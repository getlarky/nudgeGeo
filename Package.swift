// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nudgeGeo",
    platforms: [.iOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "nudgeGeo",
            targets: ["nudgeGeo"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        //
        // Using 'path', we can depend on a local package that's
        // located at a given path relative to our package's folder:
        //.package(path: "../nudgeBase"),
        .package(
        //  name: "nudgeBase",
            url: "git@github.com:getlarky/nudgeBase.git",
            .upToNextMajor(from: "1.0.0")
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "nudgeGeo",
//            dependencies: ["NudgeBase"]
            dependencies: [
                .product(name: "nudgeBase", package: "nudgeBase"),
            ]
        ),
        .testTarget(
            name: "nudgeGeoTests",
            dependencies: ["nudgeGeo", "nudgeBase"]),
    ],
    swiftLanguageVersions: [.v5]
)
