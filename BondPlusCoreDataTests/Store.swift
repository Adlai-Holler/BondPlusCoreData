
import Foundation
import CoreData

@objc (Store)
class Store: Base {

    @NSManaged var name: String
    @NSManaged var items: NSSet
  
  override static func objectMapping() -> EKManagedObjectMapping {
    let s = super.objectMapping()
    s.mapPropertiesFromArray(["name", "uuid"])
    s.hasMany(Item.self, forKeyPath: "items")
    return s
  }
}
