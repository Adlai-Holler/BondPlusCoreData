
import CoreData
import Nimble
import Quick
import BondPlusCoreData
import Bond
import AlecrimCoreData

class DataContext: Context {
  var stores:      Table<Store>     { return Table<Store>(context: self) }
  var items: Table<Item> { return Table<Item>(context: self) }
}

class NSFetchedResultsDynamicArraySpec: QuickSpec {
  override func spec() {

    var context: DataContext!
    var store: Store!
    var importMore: (() -> ())!
    beforeEach {
      let bundle = NSBundle(forClass: self.classForCoder)
      // create DB
      AlecrimCoreData.Config.modelBundle = bundle
      context = DataContext(stackType: .InMemory, managedObjectModelName: "BondPlusCoreDataTests", storeOptions: nil)
      
      // load seed
      
      let url = bundle.URLForResource("SeedData", withExtension: "json")!
      let file = NSInputStream(URL: url)!
      file.open()
      var parseError: NSError?
      let seedData = NSJSONSerialization.JSONObjectWithStream(file, options: .allZeros, error: &parseError)! as! [String: AnyObject]
      file.close()
      
      store = EKManagedObjectMapper.objectFromExternalRepresentation(seedData["store"]! as! [NSObject: AnyObject], withMapping: Store.objectMapping(), inManagedObjectContext: context.managedObjectContext) as! Store
      context.managedObjectContext.processPendingChanges()
      importMore = {
        let url = bundle.URLForResource("MoreData", withExtension: "json")!
        let file = NSInputStream(URL: url)!
        file.open()
        var parseError: NSError?
        let moreData = NSJSONSerialization.JSONObjectWithStream(file, options: .allZeros, error: &parseError)! as! [String: AnyObject]
        file.close()
        let newItems = EKManagedObjectMapper.arrayOfObjectsFromExternalRepresentation(moreData["items"]! as! [[String: AnyObject]], withMapping: Item.objectMapping(), inManagedObjectContext: context.managedObjectContext) as! [Item]
        store.mutableSetValueForKey("items").addObjectsFromArray(newItems)
        context.managedObjectContext.processPendingChanges()
      }
    }
    
    describe("Test Import") {

      it("should load the store correctly") {
        expect(store.name).to(equal("Adlai's Grocery"))
      }
      
      it("should load store.items correctly") {
        expect(store.items.count).to(equal(6))
      }
      
      it("should load item attributes correctly") {
        let anyItem = store.items.anyObject()! as! Item
        let expectedItemNames = Set(["Apple", "Banana", "Cherry", "Asparagus", "Broccoli", "Celery"])
        let actualItemNames = Set(context.items.toArray().map { $0.name })
        expect(actualItemNames).to(equal(expectedItemNames))
      }
      
    }
    
    describe("Fetched Results Array") {
      var array: NSFetchedResultsDynamicArray<Item>!
      var sectionBond: ArrayBond<NSFetchedResultsSectionDynamicArray<Item>>!

      beforeEach {
        let importantStore = context.stores.filterBy(attribute: "uuid", value: "2AB5041B-EF80-4910-8105-EC06B978C5DE").first()!
        let fr = context.items
          .filterBy(attribute: "store", value: importantStore)
          .sortBy("itemType", ascending: true)
          .thenByAscending("name")
          .toFetchRequest()
        let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: context.managedObjectContext, sectionNameKeyPath: "itemType", cacheName: nil)
        array = NSFetchedResultsDynamicArray(fetchedResultsController: frc)
        sectionBond = ArrayBond()
        array ->> sectionBond
      }
      
      it("should report correct number of sections") {
        expect(array.count).to(equal(2))
      }
      
      it("should handle deleting the last section correctly") {
        var removedSections = [Int]()
        sectionBond.willRemoveListener = {array, indices in
          removedSections += indices
        }

        context.items.filterBy(attribute: "itemType", value: "veggie").delete()
        context.managedObjectContext.processPendingChanges()
        expect(removedSections).to(equal([1]))
        expect(array.count).to(equal(1))
      }

      it("should handle deleting all items correctly") {
        var removedSections = [Int]()
        sectionBond.willRemoveListener = {array, indices in
          removedSections += indices
        }
        
        context.items.delete()
        context.managedObjectContext.processPendingChanges()
        for item in context.items {
          println("item: \(item)")
        }
        expect(Set(removedSections)).to(equal(Set([0,1])))
        expect(array.count).to(equal(0))
      }
      
      it("should handle delete at 0,0 correctly") {
        let firstSectionBond = ArrayBond<Item>()
        var removedIndices = [Int]()
        firstSectionBond.willRemoveListener = { array, indices in
          removedIndices += indices
        }
        array[0] ->> firstSectionBond
        context.managedObjectContext.deleteObject(array[0][0])
        context.managedObjectContext.processPendingChanges()

        expect(removedIndices).to(equal([0]))
        expect(array.count).to(equal(2))
        expect(array[0].count).to(equal(2))
        expect(array[0].first!.name).to(equal("Banana"))
      }
      
      it("should handle inserting many items (potentially out-of-order) correctly") {
        let firstSectionBond = ArrayBond<Item>()
        var insertedIndices = [Int]()
        println("Items: \(array[0].value)")
        firstSectionBond.willInsertListener = { array, indices in
          insertedIndices += indices
        }
        array[0] ->> firstSectionBond
        importMore()
        println("Items: \(array[0].value)")
        expect(insertedIndices).to(equal(Array(3...8)))
      }

      it("should handle update at 1,1 correctly") {
        let lastSectionBond = ArrayBond<Item>()
        var updatedIndices = [Int]()
        lastSectionBond.willUpdateListener = { array, indices in
          updatedIndices = indices
        }
        array[1] ->> lastSectionBond
        let item = array[1][1]
        item.count--
        context.managedObjectContext.processPendingChanges()
        
        expect(updatedIndices).to(equal([1]))
      }
      
      it("should handle inserting a section at index 1 correctly") {
        let sectionsBond = ArrayBond<NSFetchedResultsSectionDynamicArray<Item>>()
        var insertedSections = [Int]()
        sectionsBond.willInsertListener = { array, indices in
          insertedSections += indices
        }
        array ->> sectionsBond
        let newItem = context.items.createEntity()
        newItem.uuid = NSUUID().UUIDString
        newItem.name = "Ground beef"
        newItem.count = 10
        newItem.itemType = "meat"
        newItem.store = store
        context.managedObjectContext.processPendingChanges()
        expect(insertedSections).to(equal([1]))
      }
    }
    
  }
}
