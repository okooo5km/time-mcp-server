// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import JSONSchemaBuilder
import MCPServer
import OSLog

// Define version information
let APP_VERSION = "0.1.0"
let APP_NAME = "time-mcp-server"

let mcpLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier.map { "\($0).mcp" } ?? "tech.5km.time.mcp-server", category: "mcp")

// Parse command line arguments
func processCommandLineArguments() -> Bool {
    let arguments = CommandLine.arguments

    if arguments.contains("--version") || arguments.contains("-v") {
        print("\(APP_NAME) version \(APP_VERSION)")
        return false
    }

    if arguments.contains("--help") || arguments.contains("-h") {
        printHelp()
        return false
    }

    return true
}

// Display help information
func printHelp() {
    print(
        """
        \(APP_NAME) - A time server for MCP

        USAGE:
            \(APP_NAME) [OPTIONS]

        OPTIONS:
            -h, --help                 Show this help message and exit
            -v, --version              Show version information and exit

        DESCRIPTION:
            This MCP server provides time-related capabilities,
            enabling getting current time and converting between timezones.
        """)
}

// Only run the server if no special command line arguments are provided
if processCommandLineArguments() {
    let transport = Transport.stdio()
    func proxy(_ transport: Transport) -> Transport {
        var sendToDataSequence: AsyncStream<Data>.Continuation?
        let dataSequence = AsyncStream<Data>.init { continuation in
            sendToDataSequence = continuation
        }

        Task {
            for await data in transport.dataSequence {
                mcpLogger.info("Reading data from transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
                sendToDataSequence?.yield(data)
            }
        }

        return Transport(
            writeHandler: { data in
                mcpLogger.info("Writing data to transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
                try await transport.writeHandler(data)
            },
            dataSequence: dataSequence)
    }

    do {
        let server = try await MCPServer(
            info: Implementation(name: APP_NAME, version: APP_VERSION),
            capabilities: ServerCapabilityHandlers(tools: [
                get_current_time,
                convert_time,
            ]),
            transport: proxy(transport))

        print("\(APP_NAME) v\(APP_VERSION) started successfully")
        print("Time MCP Server running on stdio")

        try await server.waitForDisconnection()
    } catch {
        print("Error starting server: \(error)")
        exit(1)
    }
}
