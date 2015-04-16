
import Foundation
import CoreData

@objc (Item)
class Item: Base {

    @NSManaged var name: String
    @NSManaged var count: Int32
    @NSManaged var store: Store
    @NSManaged var itemType: String

  override class func objectMapping() -> EKManagedObjectMapping {
    let s = super.objectMapping()
    s.mapPropertiesFromArray(["name", "count", "itemType"])
    return s
  }
}

