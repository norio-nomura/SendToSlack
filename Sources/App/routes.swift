import Vapor

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    // from DockerHub to Slack
    router.post(DockerHubPayload.self, at: "from-docker-hub") { req, payload -> EventLoopFuture<Response> in
        guard let slackWebhookURL = Environment.get("SLACK_WEBHOOK_URL") else {
            return req.eventLoop.newSucceededFuture(result: req.makeResponse(http: .init(status: .internalServerError)))
        }

        let repoName = payload.repository.repo_name
        let tag = payload.push_data.tag
        let pusher = payload.push_data.pusher
        let repoURL = payload.repository.repo_url
        let text = "New image was pushed to \(repoName):\(tag) by \(pusher)\n\(repoURL)"
        let slackPayload = SlackPayload(text: text, username: "dockerhub", icon_emoji: ":whale:")
        let headers: HTTPHeaders = ["Content-Type": "application/json; charset=utf-8"]
        return try req.client().post(slackWebhookURL, headers: headers) { try $0.content.encode(json: slackPayload) }
    }
}

struct DockerHubPayload: Decodable, RequestDecodable {
    struct PushData: Decodable {
        let pusher: String
        let tag: String
    }
    struct Repository: Decodable {
        let repo_name: String
        let repo_url: String
    }
    let push_data: PushData
    let repository: Repository

    static func decode(from req: Request) throws -> Future<DockerHubPayload> {
        return try req.content.decode(DockerHubPayload.self)
    }
}

struct SlackPayload: Encodable {
    let text: String
    let username: String
    let icon_emoji: String
}
