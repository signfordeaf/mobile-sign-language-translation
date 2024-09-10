# SignForDeaf Mobile Sign Language

## 🛠️ Install Package    
### Swift Package Manager
Add this package to your project using Swift Package Manager in Xcode.

   1. Open your project in Xcode.
   2. Select **Add Packages** from the **File** menu.
   3. Enter the following GitHub repo URL:
        
    https://github.com/signfordeaf/mobile-sign-language-translation.git
  
### Manual Installation

   1. Clone this repository.
   2. Copy it to your project and include the Swift files in the package into the project.


## 🧑🏻‍💻 Usage

###  📄SceneDelegate.swift
   Activate the package with the API key and request URL given to you on this page.
```swift
...
import SignForDeaf
...

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    let signForDeaf = SignForDeafSign()

    ...

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        ...
    
        signForDeaf.activate(apiKey: "YOUR_API_KEY", requestUrl: "REQUEST_URL")

        ...
        
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    ...
```
### 📄ViewController.swift
   Add the code on the existing ViewController.

```swift
...
import SignForDeaf
...

class ViewController: UIViewController {

    let signForDeaf = SignForDeafSign()
    
    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        signForDeaf.signTranslateInMenu(in: view)
        textView.isSelectable = true
    }
}

```

![Image](https://imgur.com/JqwGw2k.png)
        

        

        
