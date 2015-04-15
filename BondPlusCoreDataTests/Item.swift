
import Foundation
import CoreData

@objc (Item)
class Item: Base {

    @NSManaged var name: String
    @NSManaged var count: Int32
    @NSManaged var store: Store
    @NSManaged var itemType: String

  override static func objectMapping() -> EKManagedObjectMapping {
    let s = super.objectMapping()
    s.mapPropertiesFromArray(["name", "uuid", "count", "itemType"])
    return s
  }
}

