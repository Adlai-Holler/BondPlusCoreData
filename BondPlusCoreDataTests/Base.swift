
import Foundation
import CoreData

@objc (Base)
class Base: EKManagedObjectModel {

    @NSManaged var uuid: String
  override class func objectMapping() -> EKManagedObjectMapping {
    let s = super.objectMapping()
    s.primaryKey = "uuid"
    s.mapPropertiesFromArray(["uuid"])
    return s
  }
}
