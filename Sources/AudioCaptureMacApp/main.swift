import Foundation
import Cocoa

let app = NSApplication.shared
let delegate = AudioServerApp()
app.delegate = delegate

// 禁用默认菜单
app.setActivationPolicy(.regular)

app.run() 