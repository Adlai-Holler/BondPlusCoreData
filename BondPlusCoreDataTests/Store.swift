
import Foundation
import CoreData

@objc (Store)
class Store: Base {

    @NSManaged var name: String
    @NSManaged var items: NSSet
  
  override class func objectMapping() -> EKManagedObjectMapping {
    let s = super.objectMapping()
    s.mapPropertiesFromArray(["name"])
    s.hasMany(Item.self, forKeyPath: "items")
    return s
  }
}
