import Vapor

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    router.post(DockerHubPayload.self, at: "from-docker-hub", use: postToSlack)
    router.post(HerokuPayload.self, at: "from-heroku", use: postToSlack)
}

// MARK: Slack
struct SlackPayload: Encodable {
    let text: String, username, icon_emoji: String?
}

protocol SlackPayloadConvertible {
    func slackPayload() -> SlackPayload
    static var webhookURL: String { get }
}

func postToSlack<T: RequestDecodable>(_ request: Request, payload: T) throws -> EventLoopFuture<Response> {
    guard let payload = (payload as? SlackPayloadConvertible) else {
        let response = request.makeResponse(http: .init(status: .internalServerError))
        return request.eventLoop.newSucceededFuture(result: response)
    }
    let headers: HTTPHeaders = ["Content-Type": "application/json; charset=utf-8"]
    return try request.client().post(type(of: payload).webhookURL, headers: headers) {
        try $0.content.encode(json: payload.slackPayload())
    }
}

let slackWebhookURL = Environment.get("SLACK_WEBHOOK_URL")!

// MARK: - from-docker-hub
struct DockerHubPayload: Decodable, RequestDecodable, SlackPayloadConvertible {
    struct PushData: Decodable {
        let pusher, tag: String
    }
    struct Repository: Decodable {
        let repo_name, repo_url: String
    }
    let push_data: PushData, repository: Repository

    // SlackPayloadConvertible
    func slackPayload() -> SlackPayload {
        return .init(text: """
            New image was pushed to \(repository.repo_name):\(push_data.tag) by \(push_data.pusher)
            \(repository.repo_url)
            """, username: "DockerHub", icon_emoji: nil)
    }
    static let webhookURL = Environment.get("SLACK_WEBHOOK_URL_FOR_DOCKER_HUB") ?? slackWebhookURL
}

// MARK: - from-heroku
struct HerokuPayload: Decodable, RequestDecodable, SlackPayloadConvertible {
    struct App: Decodable {
        let name: String
    }
    struct Data: Decodable {
        let app: App, output_stream_url: String?, status: String
    }
    let action, resource: String, data: Data

    // SlackPayloadConvertible
    func slackPayload() -> SlackPayload {
        let text = "\(data.app.name) \(action)s \(resource): \(data.status)" +
            (data.output_stream_url.map { "\n\($0)" } ?? "")
        return SlackPayload(text: text, username: "Heroku", icon_emoji: nil)
    }

    static let webhookURL = Environment.get("SLACK_WEBHOOK_URL_FOR_HEROKU") ?? slackWebhookURL
}

// MARK: - RequestDecodable
extension RequestDecodable where Self: Decodable {
    static func decode(from req: Request) throws -> Future<Self> {
        return try req.content.decode(Self.self)
    }
}
