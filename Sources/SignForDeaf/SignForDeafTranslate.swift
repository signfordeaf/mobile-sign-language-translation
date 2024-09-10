//BETA

//import SwiftUI
//
//public class SignForDeafTranslate {
//    public init() {}
//    
//   public func findTexts(on view: AnyView) {
//        // UIKit ile bir hosting controller oluştur
//        let hostingController = UIHostingController(rootView: view)
//        
//        // Text'leri bulmak için bir UIView içinde arama yapma
//        let viewController = hostingController.rootView
//        searchTexts(in: viewController)
//    }
//    
//    private func searchTexts(in view: Any) {
//        let mirror = Mirror(reflecting: view)
//        
//        for child in mirror.children {
//            if let text = child.value as? Text {
//                print("Found Text: \(text)")
//                
//            } else {
//                searchTexts(in: child.value)
//            }
//        }
//    }
//}
