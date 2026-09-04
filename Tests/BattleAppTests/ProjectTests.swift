import Foundation
import Testing

struct Objects {
    let all: [String: Any]

    subscript(_ name: Any?) -> [String: Any] {
        all[name as? String ?? ""] as? [String: Any] ?? [:]
    }

    static func word(_ fields: [String: Any], _ key: String) -> String {
        fields[key] as? String ?? ""
    }

    static func list(_ fields: [String: Any], _ key: String) -> [String] {
        (fields[key] as? [Any])?.compactMap { $0 as? String } ?? []
    }

    static func minimumIOS(_ manifest: String) -> String {
        let clause = manifest.components(separatedBy: ".iOS(").dropFirst().first ?? ""
        let named = (clause.components(separatedBy: ")").first ?? "").drop { !$0.isNumber }
        let version = named.filter { $0.isNumber || $0 == "." }
        return version.contains(".") ? version : version + ".0"
    }

    static func names(in text: String) -> [String] {
        var found: [String] = []
        var run = ""
        for character in text + " " {
            if character.isLetter || character.isNumber {
                run.append(character)
                continue
            }
            if run.count == 24, run.allSatisfy({ $0.isNumber || ("A"..."F").contains($0) }) {
                found.append(run)
            }
            run = ""
        }
        return found
    }
}

struct Picture {
    struct Fault: Error, CustomStringConvertible {
        let description: String
    }

    static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    static func number(_ bytes: [UInt8], _ at: Int) -> Int {
        bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) }
    }

    let width: Int
    let height: Int
    let depth: Int
    let colour: Int
    let kinds: [String]

    init(_ bytes: [UInt8]) throws {
        guard bytes.starts(with: Picture.signature) else {
            throw Fault(description: "not a PNG")
        }
        var kinds: [String] = []
        var at = Picture.signature.count
        while at < bytes.count {
            guard at + 12 <= bytes.count else {
                throw Fault(description: "a chunk starting at byte \(at) runs off the end")
            }
            let length = Picture.number(bytes, at)
            guard at + 12 + length <= bytes.count else {
                throw Fault(description: "the chunk at byte \(at) claims \(length) bytes it lacks")
            }
            kinds.append(String(decoding: bytes[(at + 4)..<(at + 8)], as: UTF8.self))
            at += 12 + length
        }
        guard kinds.first == "IHDR", Picture.number(bytes, 8) == 13 else {
            throw Fault(description: "no header chunk opens the file: \(kinds)")
        }
        guard kinds.last == "IEND", kinds.contains("IDAT") else {
            throw Fault(description: "the file is not a whole image: \(kinds)")
        }
        width = Picture.number(bytes, 16)
        height = Picture.number(bytes, 20)
        depth = Int(bytes[24])
        colour = Int(bytes[25])
        self.kinds = kinds
    }
}

@Suite struct ProjectTests {
    static let isas = [
        "PBXBuildFile", "PBXFileReference", "PBXFileSystemSynchronizedRootGroup",
        "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject",
        "PBXResourcesBuildPhase", "PBXSourcesBuildPhase", "XCBuildConfiguration",
        "XCConfigurationList", "XCLocalSwiftPackageReference", "XCSwiftPackageProductDependency",
    ]

    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    static let folder = repository.appendingPathComponent("App")
    static let project = folder.appendingPathComponent(
        "RockPaperScissors.xcodeproj/project.pbxproj")
    static let scheme = folder.appendingPathComponent(
        "RockPaperScissors.xcodeproj/xcshareddata/xcschemes/RockPaperScissors.xcscheme")

    @Test func theProjectIsShapedAsXcodeWroteIt() throws {
        let text = try String(contentsOf: ProjectTests.project, encoding: .utf8)
        #expect(text.hasPrefix("// !$*UTF8*$!\n"))

        var format = PropertyListSerialization.PropertyListFormat.openStep
        let read = try PropertyListSerialization.propertyList(
            from: Data(text.utf8), options: [], format: &format)
        let file = try #require(read as? [String: Any])
        #expect(format == .openStep)
        #expect(
            Set(file.keys) == ["archiveVersion", "classes", "objectVersion", "objects", "rootObject"]
        )

        let objects = Objects(all: try #require(file["objects"] as? [String: Any]))
        for name in objects.all.keys {
            #expect(ProjectTests.isas.contains(Objects.word(objects[name], "isa")), "\(name)")
        }
        var mentions: [String: Int] = [:]
        for name in Objects.names(in: text) { mentions[name, default: 0] += 1 }
        #expect(Set(mentions.keys) == Set(objects.all.keys))
        for (name, count) in mentions { #expect(count > 1, "\(name) is never referred to") }

        let project = objects[file["rootObject"]]
        #expect(Objects.word(project, "isa") == "PBXProject")
        let main = objects[project["mainGroup"]]
        #expect(Objects.word(main, "isa") == "PBXGroup")
        let products = objects[project["productRefGroup"]]
        #expect(Objects.word(products, "isa") == "PBXGroup")
        #expect(Objects.list(main, "children").count == 2)

        let targets = Objects.list(project, "targets")
        #expect(targets.count == 1)
        let target = objects[targets.first]
        #expect(Objects.word(target, "isa") == "PBXNativeTarget")
        #expect(Objects.word(target, "productType") == "com.apple.product-type.application")
        #expect(Objects.list(target, "buildRules").isEmpty)
        #expect(Objects.list(target, "dependencies").isEmpty)
        #expect(Objects.list(products, "children") == [Objects.word(target, "productReference")])
        let application = objects[target["productReference"]]
        #expect(Objects.word(application, "isa") == "PBXFileReference")
        #expect(Objects.word(application, "path") == "RockPaperScissors.app")
        let phases = Objects.list(target, "buildPhases").map { Objects.word(objects[$0], "isa") }
        #expect(
            phases == ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase"])

        let folders = Objects.list(target, "fileSystemSynchronizedGroups")
        #expect(folders.count == 1)
        let synchronised = objects[folders.first]
        #expect(Objects.word(synchronised, "isa") == "PBXFileSystemSynchronizedRootGroup")
        #expect(Objects.list(main, "children").contains(folders[0]))
        let sources = ProjectTests.folder
            .appendingPathComponent(Objects.word(synchronised, "path"))
        let swift = try FileManager.default.contentsOfDirectory(atPath: sources.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(swift.sorted() == ["RockPaperScissorsApp.swift", "RootView.swift"])

        let packages = Objects.list(project, "packageReferences")
        #expect(packages.count == 1)
        let package = objects[packages.first]
        #expect(Objects.word(package, "isa") == "XCLocalSwiftPackageReference")
        let manifest = ProjectTests.folder
            .appendingPathComponent(Objects.word(package, "relativePath"))
            .appendingPathComponent("Package.swift")
        #expect(FileManager.default.fileExists(atPath: manifest.standardizedFileURL.path))
        let declared = Objects.minimumIOS(try String(contentsOf: manifest, encoding: .utf8))
        let dependencies = Objects.list(target, "packageProductDependencies")
        #expect(dependencies.count == 1)
        let dependency = objects[dependencies.first]
        #expect(Objects.word(dependency, "isa") == "XCSwiftPackageProductDependency")
        #expect(Objects.word(dependency, "productName") == "BattleApp")
        let linked = objects.all.keys.filter { Objects.word(objects[$0], "isa") == "PBXBuildFile" }
        #expect(linked.count == 1)
        #expect(Objects.word(objects[linked.first], "productRef") == dependencies[0])
        let frameworks = objects.all.keys
            .filter { Objects.word(objects[$0], "isa") == "PBXFrameworksBuildPhase" }
        #expect(Objects.list(objects[frameworks.first], "files") == linked)

        for list in [project["buildConfigurationList"], target["buildConfigurationList"]] {
            let configurations = objects[list]
            #expect(Objects.word(configurations, "isa") == "XCConfigurationList")
            #expect(Objects.word(configurations, "defaultConfigurationName") == "Release")
            let both = Objects.list(configurations, "buildConfigurations")
            #expect(both.map { Objects.word(objects[$0], "name") } == ["Debug", "Release"])
        }
        let settings = Objects
            .list(objects[target["buildConfigurationList"]], "buildConfigurations")
            .map { objects[$0]["buildSettings"] as? [String: Any] ?? [:] }
        #expect(settings.count == 2)
        #expect((settings[0] as NSDictionary) == (settings[1] as NSDictionary))
        #expect(Objects.word(settings[0], "TARGETED_DEVICE_FAMILY") == "1")
        #expect(Objects.word(settings[0], "IPHONEOS_DEPLOYMENT_TARGET") == declared)
        #expect(Objects.word(settings[0], "CODE_SIGN_STYLE") == "Automatic")
        #expect(Objects.word(settings[0], "ONLY_ACTIVE_ARCH") == "YES")
        #expect(!Objects.word(settings[0], "PRODUCT_BUNDLE_IDENTIFIER").isEmpty)
        #expect(
            Objects.word(settings[0], "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone")
                == "UIInterfaceOrientationPortrait")
        let orientations = text.components(separatedBy: "UIInterfaceOrientation").dropFirst()
        #expect(orientations.count == 2)
        for orientation in orientations { #expect(orientation.hasPrefix("Portrait")) }
        let walker = try #require(FileManager.default.enumerator(atPath: ProjectTests.folder.path))
        for case let step as String in walker { #expect(!step.hasSuffix("Info.plist"), "\(step)") }

        let scheme = try String(contentsOf: ProjectTests.scheme, encoding: .utf8)
        let blueprints = scheme.components(separatedBy: "BlueprintIdentifier = \"").dropFirst()
        #expect(blueprints.count == 3)
        for blueprint in blueprints { #expect(blueprint.hasPrefix("\(targets[0])\"")) }
        let launch = try #require(scheme.components(separatedBy: "<LaunchAction").last)
        let attributes = try #require(launch.components(separatedBy: ">").first)
        #expect(attributes.contains("buildConfiguration = \"Release\""))
    }

    @Test func theHomeScreenIconIsWiredAndInAFormAppleAccepts() throws {
        let text = try String(contentsOf: ProjectTests.project, encoding: .utf8)
        let file = try #require(
            PropertyListSerialization.propertyList(from: Data(text.utf8), options: [], format: nil)
                as? [String: Any])
        let objects = Objects(all: try #require(file["objects"] as? [String: Any]))
        let target = objects[Objects.list(objects[file["rootObject"]], "targets").first]
        let named = Objects.list(objects[target["buildConfigurationList"]], "buildConfigurations")
            .map {
                Objects.word(
                    objects[$0]["buildSettings"] as? [String: Any] ?? [:],
                    "ASSETCATALOG_COMPILER_APPICON_NAME")
            }
        let icon = try #require(named.first)
        #expect(named == [icon, icon])
        #expect(!icon.isEmpty)

        let synchronised = objects[Objects.list(target, "fileSystemSynchronizedGroups").first]
        let sources = ProjectTests.folder.appendingPathComponent(Objects.word(synchronised, "path"))
        let walker = try #require(FileManager.default.enumerator(atPath: sources.path))
        let sets = walker.compactMap { $0 as? String }
            .map { sources.appendingPathComponent($0) }
            .filter {
                $0.lastPathComponent == "\(icon).appiconset"
                    && $0.deletingLastPathComponent().pathExtension == "xcassets"
            }
        #expect(sets.count == 1)
        let set = try #require(sets.first)
        let root = set.deletingLastPathComponent().appendingPathComponent("Contents.json")
        #expect(FileManager.default.fileExists(atPath: root.path))
        let read = try JSONSerialization.jsonObject(
            with: try Data(contentsOf: set.appendingPathComponent("Contents.json")))
        let entries = try #require(read as? [String: Any])
        let images = try #require(entries["images"] as? [[String: Any]])
        let plain = images.filter { $0["appearances"] == nil }
        #expect(plain.count == 1)
        let image = try #require(plain.first)
        #expect(Objects.word(image, "idiom") == "universal")
        #expect(Objects.word(image, "platform") == "ios")
        #expect(Objects.word(image, "size") == "1024x1024")
        let filename = Objects.word(image, "filename")
        #expect(!filename.isEmpty)

        let bytes = [UInt8](try Data(contentsOf: set.appendingPathComponent(filename)))
        let picture = try Picture(bytes)
        #expect(picture.width == 1024)
        #expect(picture.height == picture.width)
        #expect(picture.depth == 8)
        #expect(![4, 6].contains(picture.colour))
        #expect(!picture.kinds.contains("tRNS"))
    }
}
