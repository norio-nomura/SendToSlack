import App
import Foundation

let signalHandler: @convention(c) (Int32) -> Swift.Void = { signo in
    exit(128 + signo)
}

// https://devcenter.heroku.com/articles/dynos#shutdown
signal(SIGTERM, signalHandler)

try app(.detect()).run()
