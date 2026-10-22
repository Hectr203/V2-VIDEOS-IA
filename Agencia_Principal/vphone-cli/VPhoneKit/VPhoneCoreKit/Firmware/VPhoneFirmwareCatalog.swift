import Foundation

// MARK: - VPhoneFirmwarePairing

/// A known restore-IPSW ↔ cloudOS pairing for one guest device, with friendly
/// names for prompts and the direct download URLs `fw prepare` consumes.
public struct VPhoneFirmwarePairing: Sendable, Equatable {
    /// The guest's product type: `iPhone17,3`, or the iPad model `fw prepare
    /// --device` picks from an IPSW that covers several.
    public let device: String
    public let iosName: String
    public let iosURL: String
    public let cloudosName: String
    public let cloudosURL: String

    public init(
        device: String = VPhoneFirmwareCatalog.device,
        iosName: String,
        iosURL: String,
        cloudosName: String,
        cloudosURL: String,
    ) {
        self.device = device
        self.iosName = iosName
        self.iosURL = iosURL
        self.cloudosName = cloudosName
        self.cloudosURL = cloudosURL
    }
}

// MARK: - VPhoneCloudOSOption

public struct VPhoneCloudOSOption: Sendable, Equatable {
    public let name: String
    public let url: String
    public init(name: String, url: String) {
        self.name = name; self.url = url
    }
}

// MARK: - VPhoneFirmwareCatalog

/// The known downloadable restore/cloudOS pairings, per guest device. Prompts
/// show the friendly `iosName`/`cloudosName`; selection resolves to the URLs.
public enum VPhoneFirmwareCatalog {
    /// The iPhone model every iPhone pairing targets, and the device a catalog
    /// lookup without one means.
    public static let device = "iPhone17,3"

    // cloudOS images (one per major); referenced by multiple iPhone builds.
    // cloud264 is the 26.4 beta (23E5207q), the last cloudOS with vphone600ap:
    // every release from 26.4 (23E244) to 26.7 (23H20) has only vresearch101ap,
    // so newer builds keep pairing with it.
    static let cloud261 = "https://updates.cdn-apple.com/private-cloud-compute/399b664dd623358c3de118ffc114e42dcd51c9309e751d43bc949b98f4e31349"
    static let cloud262 = "https://updates.cdn-apple.com/private-cloud-compute/0cb00f22e0f7a8b33995b49b2bdca77f781ed6093a09c570ac21b0f012bab908"
    static let cloud263 = "https://updates.cdn-apple.com/private-cloud-compute/edc92b58ab7e2f207a6407fd0a0e1a60f7d43bf9d93325bf6d3db3e154ee5525"
    static let cloud264 = "https://updates.cdn-apple.com/private-cloud-compute/c0ecdb4b310cf5239ab2b248dd3098eec297dc5aa3bbe6ada27273262b0b8b64"

    /// The iPhone17,3 pairings, oldest first. Launchpad offers the last one by
    /// default, so the newest release stays last.
    public static let pairings: [VPhoneFirmwarePairing] = [
        .init(iosName: "iOS 18.6.2", iosURL: "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-20738/98758B5A-311E-4538-B365-FEE3D8792CDF/iPhone17,3_18.6.2_22G100_Restore.ipsw", cloudosName: "cloudOS 26.1", cloudosURL: cloud261),
        .init(iosName: "iOS 26.0", iosURL: "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40775/B7282E74-76C1-4D0A-8FAE-CE97FC2330C2/iPhone17,3_26.0_23A341_Restore.ipsw", cloudosName: "cloudOS 26.1", cloudosURL: cloud261),
        .init(iosName: "iOS 26.0.1", iosURL: "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-46329/C1717B2A-9E58-4131-A398-75D9B1D01A89/iPhone17,3_26.0.1_23A355_Restore.ipsw", cloudosName: "cloudOS 26.1", cloudosURL: cloud261),
        .init(iosName: "iOS 26.1", iosURL: "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13864/668EFC0E-5911-454C-96C6-E1063CB80042/iPhone17,3_26.1_23B85_Restore.ipsw", cloudosName: "cloudOS 26.1", cloudosURL: cloud261),
        .init(iosName: "iOS 26.2", iosURL: "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-90760/1214478F-8ED8-4AE0-B693-2F63CE0259A9/iPhone17,3_26.2_23C55_Restore.ipsw", cloudosName: "cloudOS 26.2", cloudosURL: cloud262),
        .init(iosName: "iOS 26.2.1", iosURL: "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34150/D14FB1F1-B8C5-4A20-9250-8DD35EF19BF5/iPhone17,3_26.2.1_23C71_Restore.ipsw", cloudosName: "cloudOS 26.2", cloudosURL: cloud262),
        .init(iosName: "iOS 26.3", iosURL: "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-39165/E8E603F3-A2E2-4638-8067-394754896386/iPhone17,3_26.3_23D127_Restore.ipsw", cloudosName: "cloudOS 26.3", cloudosURL: cloud263),
        .init(iosName: "iOS 26.3.1", iosURL: "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90312/17B5C7BE-C560-43BD-BA9A-7DD1E5C2FC23/iPhone17,3_26.3.1_23D8133_Restore.ipsw", cloudosName: "cloudOS 26.3", cloudosURL: cloud263),
        .init(iosName: "iOS 26.4", iosURL: "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-06082/FE21226A-B87F-4FC7-9D4B-B97A9EAF5C20/iPhone17,3_26.4_23E246_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.4.1", iosURL: "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28526/10E1E3EC-6A3E-4620-A569-8E0C4361AB77/iPhone17,3_26.4.1_23E254_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.4.2", iosURL: "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60828/A4082066-CCC4-4903-89E6-FF4801EA609C/iPhone17,3_26.4.2_23E261_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.5", iosURL: "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-63074/5E6B4A05-BDBC-45FE-9606-22B8F4315989/iPhone17,3_26.5_23F77_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.5.2", iosURL: "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-25549/1AFB1F72-E48E-476A-9C21-42B27C846C01/iPhone17,3_26.5.2_23F84_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.6", iosURL: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-58193/1F477C3E-934B-43C0-B428-753B9E005EC0/iPhone17,3_26.6_23G71_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.6.1", iosURL: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-93817/B5362BAA-F3EE-49C8-BA43-309F0DAD1362/iPhone17,3_26.6.1_23G83_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 26.6.2", iosURL: "https://updates.cdn-apple.com/2026SummerFCS/29d685ce-f70d-45a0-9823-b1cd115f3927/iPhone17,3_26.6.2_23G90_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 1", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/fullrestores/122-99394/32118457-A80B-4953-BF2A-11F74FD7D375/iPhone17,3_27.0_24A5355q_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 2", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/fullrestores/140-21207/F0510574-F649-48C5-B535-0A477E342BFB/iPhone17,3_27.0_24A5370h_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 3", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/fullrestores/140-35950/D135F5B5-C2BE-4630-8AE9-C78A6F0E8381/iPhone17,3_27.0_24A5380h_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 4", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/fullrestores/140-57108/5E816D0E-89BB-4B95-8825-6A3EDF22E509/iPhone17,3_27.0_24A5390f_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 5", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/fullrestores/140-86338/57B34BF9-3BF5-4B47-BCCA-81B282175957/iPhone17,3_27.0_24A5408d_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 6", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/ad5b3026-b03e-4b21-8bcb-96d6ea527e09/iPhone17,3_27.0_24A5418b_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 7", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/ad5a4f9d-f005-466b-bbcf-3b466040074b/iPhone17,3_27.0_24A5424a_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27 beta 8", iosURL: "https://updates.cdn-apple.com/2026SpringSeed/2d03d580-843b-4b2a-b09d-976b31c10744/iPhone17,3_27.0_24A5430a_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27.0 RC", iosURL: "https://updates.cdn-apple.com/2026FallFCS/2d0cd01d-b4f9-4a20-a1e8-f3be54570da7/iPhone17,3_27.0_24A435_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27.0", iosURL: "https://updates.cdn-apple.com/2026FallFCS/5130b3f9-3b4e-469a-b60e-93f6b310cdd9/iPhone17,3_27.0_24A437_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
        .init(iosName: "iOS 27.0.1", iosURL: "https://updates.cdn-apple.com/2026FallFCS/38dca0ee-bb5d-4132-ad13-62d57bcd6d32/iPhone17,3_27.0.1_24A446_Restore.ipsw", cloudosName: "cloudOS 26.4", cloudosURL: cloud264),
    ]

    /// iOS releases of the iPhones other than the iPhone17,3, one entry per
    /// IPSW, oldest first. Each model has an IPSW of its own. The URLs are
    /// Apple's, as ipsw.me lists them; betas and release candidates are left
    /// out.
    static let iPhoneReleases: [(devices: [String], releases: [(version: String, url: String)])] = [
        // iPhone 16 Pro
        (devices: ["iPhone17,1"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40536/E62697A1-4565-4068-867C-A64017377220/iPhone17,1_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-43810/F2F7E980-637D-43E2-95B0-086153F454D4/iPhone17,1_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12752/58F5FDED-E1C5-47ED-A530-A8454B5E1052/iPhone17,1_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91292/E0B40965-4758-4C5C-B83C-E9F75BCCE139/iPhone17,1_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34169/C32FC87E-E6D2-47D1-915A-EC741FE24B6E/iPhone17,1_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-53989/8683F123-A494-4419-82A9-DE287B1B281D/iPhone17,1_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90340/9306A4A2-C849-42B8-BF39-1FD9E2A20CE1/iPhone17,1_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-03453/2D779380-A8AB-4612-B820-43A317AE66D1/iPhone17,1_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28459/AD0EA9E1-53B4-48C8-81A3-D19DD7D8139D/iPhone17,1_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60269/F123C921-03F7-44FA-BF63-CD9F2D1F9BEF/iPhone17,1_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-75601/BB8D0F8A-1430-4123-8782-563C2005AF64/iPhone17,1_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-25812/09FF5085-9C4C-4DED-ACB2-0B0A07B46705/iPhone17,1_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57119/CBE71A83-42C2-4ED3-AAFC-190CFEF5E9C5/iPhone17,1_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-73026/F0618CC5-229F-4EE6-BCDD-3F987B287E0A/iPhone17,1_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/87a2b7df-6a1a-4c43-baa9-9b2315095b3f/iPhone17,1_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/16584c22-bd85-424c-a45d-5aa78098db98/iPhone17,1_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/59ffd938-75b6-41e5-af04-f4295ee8aeb3/iPhone17,1_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 16 Pro Max
        (devices: ["iPhone17,2"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-41023/5740BA6D-F4D8-4825-B5BE-CB70E3CF8B79/iPhone17,2_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-43738/0A1C263B-75EA-4DC1-9A0C-079BD4A650A8/iPhone17,2_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-14402/3BEC16D3-DCE3-455C-AE34-2114C57A9D3E/iPhone17,2_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91662/EA5BF9C7-FE70-4CA2-A940-9367E535E8E7/iPhone17,2_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34217/D03B52DE-E9B3-42DD-87AE-7FAB872C8272/iPhone17,2_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-59425/A84BC28C-CF4D-42B4-8B16-ABAB4F0803E9/iPhone17,2_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-89601/D42C034F-0875-4AF8-A6A7-9E5B07964EB5/iPhone17,2_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-09210/3FE1318C-6856-4C1D-B511-A668E72E880C/iPhone17,2_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28520/A337CFF5-F5D1-4C4E-BA6F-1576CFC13708/iPhone17,2_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60239/FCB4CEE1-6A25-4BCD-9D66-CADE51B21E81/iPhone17,2_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-79891/E8EE3704-C08A-4187-BFAB-3A3031499D26/iPhone17,2_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26194/0358D1F3-1C15-44F7-A711-93D2987CA188/iPhone17,2_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-58447/B097FD44-AF14-43CE-BEC0-CE218A859ADC/iPhone17,2_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-73460/FE7F3B72-D934-4017-9508-03178240D462/iPhone17,2_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/a1dbd14a-9e9d-49b3-9af6-02286d68883f/iPhone17,2_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/2f4f3b1f-a7cd-4c38-ae94-2ebd11a76253/iPhone17,2_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/3741bcd4-e0a6-43a7-bac1-74f363efb9ab/iPhone17,2_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 16 Plus
        (devices: ["iPhone17,4"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-41540/CB687B5F-0A31-4FBE-BFF9-D1069792A5DB/iPhone17,4_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44016/0CDDD881-6A8B-4960-9DF7-C8A24D6FF68C/iPhone17,4_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12124/FD18BC86-63E5-4FE1-AD33-D4B62995ECF2/iPhone17,4_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91142/728A69B0-F3DD-41B5-ADCA-B7685FFC8402/iPhone17,4_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34222/91C8E99B-8830-4E83-A9B7-47A452520F96/iPhone17,4_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-43178/1862BD5D-CE56-4250-BEF9-FA48CCC0FFFE/iPhone17,4_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90343/B08DC413-474A-4345-860F-BD012CB23696/iPhone17,4_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-02138/98EB8109-8570-45AF-9989-808E8FDFB935/iPhone17,4_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28494/0BB1EDAA-9965-49EA-AB1E-DA534A7CF372/iPhone17,4_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60841/29E88F64-8C49-4789-83D1-674B0BA4E1B3/iPhone17,4_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-79783/F7C100D3-3A04-4D4F-8CDB-5ADDA10594E1/iPhone17,4_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-25874/6B056695-9268-4775-BB6E-5C0C3ED64C20/iPhone17,4_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-58925/2F435FAA-0C75-4034-8610-3ADEF6D2E78A/iPhone17,4_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75160/D83A8969-3179-4D59-9F72-37FFC825CD9A/iPhone17,4_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/911faed2-7d37-4532-8a4a-bd60530e1b11/iPhone17,4_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/601712cb-7aa9-4914-b421-91d45da959e6/iPhone17,4_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/ff004e4f-0c2c-489a-b3c2-42b07bb962bc/iPhone17,4_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 16e
        (devices: ["iPhone17,5"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40473/648A4749-E039-441F-8207-3CCCB0DEA68F/iPhone17,5_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44366/261B2170-B316-415F-B6A2-80C41F2635E7/iPhone17,5_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13748/1A9D15D6-0015-4590-B7CF-32EAAE847EEE/iPhone17,5_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91680/D275D617-A543-46A6-A66D-70FEF31F909E/iPhone17,5_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-69799/13079A5C-BCE7-4243-8673-3A4D53B2306D/iPhone17,5_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-61657/C27364D5-1CDD-4B2A-8073-095F206A146F/iPhone17,5_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90412/C5B5B7F3-7034-43CF-8671-2564EB510B64/iPhone17,5_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-09229/FE79A39F-EAC1-4197-84A1-B85738D8D0E0/iPhone17,5_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28556/EB4B373E-CE25-4B71-A5E1-60CE9A35712B/iPhone17,5_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60273/CE3DB083-76B9-4E5D-94FB-DED041A78DAE/iPhone17,5_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-42069/B3E5E8B7-23BA-4E42-9DD5-AD3DF6EDFC0D/iPhone17,5_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26559/1BB7BFFB-0CF4-4884-8CC5-9379EAE49F35/iPhone17,5_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57347/93853233-10D5-4C30-B6CA-AD4E70581573/iPhone17,5_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-74909/1F205126-CF35-4228-852C-4033E008A83C/iPhone17,5_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/19c41505-0ca3-4039-8594-b8169550b4c6/iPhone17,5_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/d79065c6-1467-4207-b204-4c8f9d080aa1/iPhone17,5_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/096468f2-4871-44bd-bcba-5b661400d70b/iPhone17,5_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 17 Pro
        (devices: ["iPhone18,1"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-45797/04671623-D2C1-4851-B2B4-19E96540E7D9/iPhone18,1_26.0_23A345_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-50562/D2196EC3-5BC9-4694-ADF0-243489046B4D/iPhone18,1_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13936/78E94D51-CAD3-45DF-BC13-CD7D2E6E6E8F/iPhone18,1_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91375/AC7B0625-98D2-4A75-9AF2-E01F93DFF78D/iPhone18,1_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-68716/36B64BD0-F945-45BD-8905-6E01F4F916E4/iPhone18,1_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/089-58415/DFFC8F23-94E8-46C2-B60C-1BA35DDE76D3/iPhone18,1_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-89687/5CA55B41-9683-4BCC-A5F6-5D39EBF86AA1/iPhone18,1_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-01483/985F1DAD-1F04-4D76-8D79-393E165867DD/iPhone18,1_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28571/4A9F66FB-09DA-4019-8C86-F1A14996572F/iPhone18,1_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60858/9DD6EA7E-DAD8-4CAC-A7CA-F6DC55F55E9F/iPhone18,1_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-58991/67D386A6-5CBD-44D8-9E90-C6107A892180/iPhone18,1_26.5_23F77_Restore.ipsw"),
            ("26.5.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-88894/CF6FDC3F-3E68-4ADE-85AA-390E18FCE138/iPhone18,1_26.5.1_23F81_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26301/EB6F54FA-685C-4206-9233-4E5AF14A34A6/iPhone18,1_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57285/88580B31-DFDB-4502-884F-DA40EC871038/iPhone18,1_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75048/DA1909FD-EE14-421B-BB9C-A85335254485/iPhone18,1_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/f768ecdf-e037-44e6-bfa6-949b6d127c4f/iPhone18,1_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/e4bd9396-e611-4d22-b29a-0ed802448015/iPhone18,1_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/8451c50e-8b6f-4f5c-94c2-81469528464e/iPhone18,1_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 17 Pro Max
        (devices: ["iPhone18,2"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-45687/D1257A3B-15FD-4B7C-918F-24C20E9C8915/iPhone18,2_26.0_23A345_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-50536/B604C1FC-63A8-4D3F-9F48-D8DA2B3F6FA5/iPhone18,2_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13227/120921ED-C509-4448-9094-116E911F3133/iPhone18,2_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91582/DFC72BAF-5ED1-4EA6-AD28-EC152F00888B/iPhone18,2_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-96292/D73A6327-9058-4021-8AE6-05EDD1817682/iPhone18,2_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-61640/4D73254B-089A-43A3-8179-80F520F5328F/iPhone18,2_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-89691/F4F2DBF0-41AA-4B6E-ABDB-96EAB5D7CE1E/iPhone18,2_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-02792/6C4662D4-DD36-4EA9-8DC5-9EB9153CFAED/iPhone18,2_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28564/0FF93EFE-56DF-4C00-858E-B8213A4ED33D/iPhone18,2_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60865/DB8F9C6B-5DBB-4017-B160-1DE010879BB8/iPhone18,2_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-56404/B6269659-BD71-4CB7-AF7C-F8D9C3CC6E2D/iPhone18,2_26.5_23F77_Restore.ipsw"),
            ("26.5.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-88880/8FFF31F6-B39C-4572-AC7F-541BAB1F3A32/iPhone18,2_26.5.1_23F81_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26432/CF51E589-7C43-4B55-B909-CF585DAD0570/iPhone18,2_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57413/ED42973A-9AB0-41DC-B564-11A133F29F29/iPhone18,2_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75094/69BCC770-5451-4FE7-ADF4-52E2A2AB0EB3/iPhone18,2_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/1a337b3d-ffd8-424a-abc4-092b64d551ab/iPhone18,2_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/8d2fc0d7-5c81-4712-ac4e-c4a88de4cef7/iPhone18,2_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/3b7299da-a6a5-4bf6-82db-cd37f8c2d160/iPhone18,2_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 17
        (devices: ["iPhone18,3"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-41338/A4CC0565-1F51-4F4B-B303-CA52DDE0E53B/iPhone18,3_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44719/9A187866-AC58-449C-8B5A-597098F99465/iPhone18,3_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12066/4F86CB11-E6FA-47CB-96A8-527A4CBD9273/iPhone18,3_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91206/3B9DB894-526C-4B1E-9D67-AD838CEAB9A4/iPhone18,3_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-97410/74A69CBC-C68F-43AF-ACBD-3D9127A423B7/iPhone18,3_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/089-71645/C2713B5B-2752-4F35-A082-2963ED6DA5E3/iPhone18,3_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-91280/B587C50E-AFE4-43DF-954F-1EFD3637F11C/iPhone18,3_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-01484/6C4962EB-0B7E-4721-81A5-A0307FBB17EA/iPhone18,3_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28570/FEA1985C-5AF6-43BA-8A91-6F08B778B866/iPhone18,3_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60274/553CD561-76CB-4B5A-B029-23FB47055236/iPhone18,3_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-59599/450F9107-3236-4F2A-9A7B-806E99CD1568/iPhone18,3_26.5_23F77_Restore.ipsw"),
            ("26.5.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-88893/ABC2FBFD-AA2D-4FE6-A736-2F02E1BEC46A/iPhone18,3_26.5.1_23F81_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26412/773D76F3-DC28-4A7C-BA4B-D2650858E1D5/iPhone18,3_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57094/9A1B4782-299B-4868-BE2F-23736A07D105/iPhone18,3_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75080/6B80B95C-7F76-4D7A-86DE-C095321A8146/iPhone18,3_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/c2f9fa07-0acc-4038-99f4-d7a4b1ac9c06/iPhone18,3_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/b18c9502-c21d-4555-9bf7-21f3a238e6d7/iPhone18,3_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/052dd27b-a831-4746-b00a-2e6a7f5a5586/iPhone18,3_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone Air
        (devices: ["iPhone18,4"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-39795/6A1A4D22-A7DC-4C2C-A147-D4D9D4EB7D1F/iPhone18,4_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44415/65359B2E-9997-4686-B335-CEEA4524A334/iPhone18,4_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-14211/A9EC7D63-0F1D-49B9-A57B-1D0C85EE98F8/iPhone18,4_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-91442/02FFE81E-3F12-4062-B78C-5822BF18B9ED/iPhone18,4_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34147/A3A2F9E9-F393-4ACE-BE3A-F420BB1B09AC/iPhone18,4_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-36499/FCDEA0A9-965D-4532-ADDB-7154132ADB5A/iPhone18,4_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90993/98D32C32-13A6-44CD-B971-C14B07D0ECBC/iPhone18,4_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-06787/B893F5E8-6B35-451C-AC71-E6F82D1438B4/iPhone18,4_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28480/EC855F8B-2096-43ED-8D87-1F058209B743/iPhone18,4_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60829/FCA761D9-CE09-4A4A-9F6B-6F3BDFCDA3A4/iPhone18,4_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-62508/AC32AA07-3983-4F2D-B953-E2C54534DF9F/iPhone18,4_26.5_23F77_Restore.ipsw"),
            ("26.5.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-88739/AF8FDCAB-F2FE-45B5-BD3A-0DA8509AAE6C/iPhone18,4_26.5.1_23F81_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-27097/3D77FCC8-81A6-4298-8721-90F70EE21076/iPhone18,4_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57973/6338BC4D-F714-4BAF-B5D6-8786310374C8/iPhone18,4_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-73502/CCE4FF03-AB03-49A0-B259-1AD69AA7CB5F/iPhone18,4_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/c459f07a-97b9-4057-ab6d-8241040687d9/iPhone18,4_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/fdb27442-4a14-48d1-bf30-574a47241a3f/iPhone18,4_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/91255a6b-fab1-4e33-a38a-6de41a2bb61c/iPhone18,4_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPhone 17e
        (devices: ["iPhone18,5"], releases: [
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90413/DB3F26E5-E4EA-440E-89AD-41224783EBE1/iPhone18,5_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-03475/CDD56EEE-78C6-4E10-BE9E-A3E491E7850A/iPhone18,5_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28568/DA03BD6A-B629-48C6-8386-9C0C10D00740/iPhone18,5_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60276/437E50C4-A6AC-46FC-BC2C-0C990DF53C7E/iPhone18,5_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-41484/C3A82719-BEFF-4194-A5CC-494D9D336C24/iPhone18,5_26.5_23F77_Restore.ipsw"),
            ("26.5.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-88882/D5969BF4-8C08-4D55-8B88-05BFE453EDDA/iPhone18,5_26.5.1_23F81_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26279/05914D79-44CE-4676-931A-196FD4097CC7/iPhone18,5_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57120/653D93F3-501E-451B-BE75-E90751A1BAF6/iPhone18,5_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-73050/DE636DB6-94E8-4B51-9925-6D7BA82DA935/iPhone18,5_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/543c77da-97fc-4e4e-b2e2-942b8d34c723/iPhone18,5_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/dff48a54-47d4-4a76-909e-21ac46b95468/iPhone18,5_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/dad095d6-083a-4ff2-a2be-29503e316461/iPhone18,5_27.0.1_24A446_Restore.ipsw"),
        ]),
    ]

    /// iPadOS releases, one entry per iPad IPSW, oldest first. Each IPSW also
    /// covers the cellular twins, which run as their Wi-Fi model
    /// (`VPhoneGuestDevice.aliases`), so `devices` lists only the models a guest
    /// can be. The URLs are AppleDB's; betas and release candidates are left out.
    static let iPadReleases: [(devices: [String], releases: [(version: String, url: String)])] = [
        // iPad mini (A17 Pro)
        (devices: ["iPad16,1"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40200/9E916D65-39EF-49BF-9246-0F1190E93B10/iPad16,1,iPad16,2_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44520/43068DEC-6704-4E42-9F06-DB0391F44D69/iPad16,1,iPad16,2_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12753/0AC11D64-550A-4C49-A257-7EC00EE9551A/iPad16,1,iPad16,2_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-81716/33E631AB-9ADD-48EC-BA4B-344BA1740DB1/iPad16,1,iPad16,2_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34203/F9F7CE68-7EAD-4FD7-A8AC-25FC05F9E57E/iPad16,1,iPad16,2_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-60060/B1928C4A-73EA-4118-B32C-8F5CB8DB5C37/iPad16,1,iPad16,2_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90322/BF9DA0EC-EA61-4F64-9726-386B5A9F5F6D/iPad16,1,iPad16,2_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-04123/1E3F7841-247B-4FB9-A6E5-555E7B37E905/iPad16,1,iPad16,2_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28463/D1829F98-B5E6-4CFF-BA6D-3944FB6F0169/iPad16,1,iPad16,2_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60229/671D5227-99FC-4400-8B87-759B124F3A25/iPad16,1,iPad16,2_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-72606/1CDD78CE-0B50-471B-83B4-B1873BF12350/iPad16,1,iPad16,2_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26558/40877F89-3762-40A6-B87A-DCAE2D2A4640/iPad16,1,iPad16,2_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57473/555F9A51-FB16-4FDA-B60E-1AE599CB0E38/iPad16,1,iPad16,2_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-93812/387AE60F-41A6-4EBD-A1BC-E3AF66434C9C/iPad16,1,iPad16,2_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/cf7db64d-5866-4bf2-bfff-50a32f58bec3/iPad16,1,iPad16,2_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/e81c639f-1417-45aa-8a75-6f262083fe37/iPad16,1,iPad16,2_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/46399de6-53d0-47ec-baea-c203630bcee9/iPad16,1,iPad16,2_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPad (A16)
        (devices: ["iPad15,7"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40869/5E29D9F8-D82C-41AB-B999-30DB3E3AB67E/iPad15,7_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44823/3805B746-50BB-4226-AA51-A41218E4DC8B/iPad15,7_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13278/C93C2D8A-8BB5-4754-8BE8-BD894B8BD280/iPad15,7_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-80977/82AABD09-DC93-460F-A1C6-D358527CB62D/iPad15,7_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34190/1727242B-9A24-44CA-AF0A-20F2CC10DC78/iPad15,7_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-59864/C987B5A8-9A87-498B-9739-CCCA36759BF2/iPad15,7_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90330/70651A4E-5FDE-42E6-A757-11D0B10967D6/iPad15,7_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-01462/F6D80D95-3B54-47F0-8E8E-6DAA861A3615/iPad15,7_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28497/8533F29A-DB67-4CF3-A37F-D5C0AA8117BF/iPad15,7_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60819/F9C65878-32AC-438B-BA6E-ABD08D386E7E/iPad15,7_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-36065/9064647F-C48C-4213-B5E6-7AA5E3377A7C/iPad15,7_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26993/CFCC3254-9102-428F-94FA-FC61C2CE0706/iPad15,7_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-58697/CB8C4B63-F794-4EED-AD2F-15297E14B69E/iPad15,7_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-73569/4627D405-B284-43D6-AA1E-FF775D807C89/iPad15,7_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/ac34b338-5954-4440-acd7-eb623372b116/iPad15,7_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/cbdb3e7c-6078-4116-81f5-9ca857711975/iPad15,7_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/224ac70a-6dd1-4fd4-8d3a-45f3c4026600/iPad15,7_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPad Air (M3), 11- and 13-inch
        (devices: ["iPad15,3", "iPad15,5"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-41910/8ED9149B-5FAA-46CA-BFF1-4F1AC5B70E05/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-44466/6E2168C0-561F-40A5-84C0-1E71B0EED75D/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12827/9A6C58AA-2A00-4773-8A69-3CB0D7C21AF6/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-79199/1F1CC2FD-45B0-4A5C-A69C-16DB618D0ADF/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34196/5C6B83F9-16A3-40E7-961F-6AE05572177E/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-61590/387157F3-CEBD-4FF1-8E06-4E4F3EF185C1/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-89616/C5FDAFB4-B15A-482B-963E-3E8807692007/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-07874/61C4FAFB-925D-4CE4-95C7-04E0DF9E7484/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28513/B7952EA1-2E7B-4B5A-9098-08C7FB0B3065/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60254/E881A5D5-8452-4196-964E-A8614FF16AA6/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-70574/10C3FA3A-E70C-4A46-82AE-34C2320F8023/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-26796/75B1A13D-F146-4198-A1A0-F71D4E58A07B/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57887/5713215E-7923-4102-8D3C-0B03DA847759/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-93813/53D9BF7A-EC71-4F4B-B97A-ED3F8922CBEF/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/3ddb0f1f-46ed-48f4-aaad-9837e83144fa/iPad15,3,iPad15,4,iPad15,5,iPad15,6_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/0b0970ac-f84c-4323-82ab-f153c69c89b7/iPad15,3,iPad15,4,iPad15,5,iPad15,6_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/7cabbf62-92ba-48e9-afaa-d8ec39313fa8/iPad15,3,iPad15,4,iPad15,5,iPad15,6_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPad Pro (M4), 11- and 13-inch
        (devices: ["iPad16,3", "iPad16,5"], releases: [
            ("26.0", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-40671/F76C0CC9-322F-4F2B-B2D9-5DA6F0F7C160/iPad_Pro_M4_26.0_23A341_Restore.ipsw"),
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-45848/6007892D-DB8F-4F7F-BC2A-DFE468C1FB89/iPad_Pro_M4_26.0.1_23A355_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-12294/8B8B66E4-24AC-4D54-BBD3-F9D35832E74D/iPad_Pro_M4_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-81719/ECE32135-FCBE-4096-92DE-E12D6C3F4160/iPad_Pro_M4_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-21543/5EB13756-48DB-4A4E-A3F0-C36A1172C6D8/iPad_Pro_M4_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-61663/76E85FB6-6A25-4844-A3DD-FB15EA9D1466/iPad_Pro_M4_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-91004/34DCB1DE-C509-4AB2-96FC-A8FA83246209/iPad_Pro_M4_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-02774/55F8FBBE-EAD4-4FE9-B62F-3D75E28B8D3B/iPad_Pro_M4_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28530/6E00E32B-0B47-4F71-80CE-5380561EFE27/iPad_Pro_M4_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60853/499BEF59-2EC1-4E2D-AC10-B0122FF4B5DD/iPad_Pro_M4_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-64200/E70453A1-F1E6-405E-A39A-267AED87CCC2/iPad_Pro_M4_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-25404/3C9A5919-8296-4275-A2B7-E5D0C2162572/iPad_Pro_M4_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57655/D1CB1E3E-79BC-4304-8545-C667E82DF2AF/iPad_Pro_M4_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-74906/D199C9EE-0CA2-4BAC-B39D-EAAE6F711136/iPad_Pro_M4_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/9f44484a-c9ac-4a85-8240-435894b1464f/iPad_Pro_M4_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/459900f0-887c-4dee-a819-3395e7bf67b5/iPad_Pro_M4_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/7532c1a2-9d94-419d-ad88-bd0e3a0e2bbc/iPad_Pro_M4_27.0.1_24A446_Restore.ipsw"),
        ]),
        // iPad Pro (M5), 11- and 13-inch
        (devices: ["iPad17,1", "iPad17,3"], releases: [
            ("26.0.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/093-88260/57436729-3132-41A2-89D1-52AB75C7FD2C/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.0.1_23A8466_Restore.ipsw"),
            ("26.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-13189/7F17B1CD-05CE-421A-AFEC-AD7F5ED4CF95/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.1_23B85_Restore.ipsw"),
            ("26.2", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/089-79327/60AAF9BE-FCDB-4478-B5CF-A65E1177346F/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.2_23C55_Restore.ipsw"),
            ("26.2.1", "https://updates.cdn-apple.com/2025FallFCS/fullrestores/047-34213/B71D7BDD-767E-4597-80E7-CBA54CA737E1/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.2.1_23C71_Restore.ipsw"),
            ("26.3", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-61625/38C75A42-C0A5-49AB-8DB1-0D31618617E2/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.3_23D127_Restore.ipsw"),
            ("26.3.1", "https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-90311/A91F8DEB-EF60-4571-8A16-81154C15F6F5/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.3.1_23D8133_Restore.ipsw"),
            ("26.4", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-09212/2E89B1A1-1462-45AD-AB0F-301FCBC56358/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.4_23E246_Restore.ipsw"),
            ("26.4.1", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-28528/40A1B358-2D66-4974-9441-0ED88BCC5628/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.4.1_23E254_Restore.ipsw"),
            ("26.4.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-60809/BEBBE1E0-1A14-436B-8541-6F082F04DEB7/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.4.2_23E261_Restore.ipsw"),
            ("26.5", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-39566/3DBC2822-E9B6-4D5B-9A74-A3B5E84315DF/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.5_23F77_Restore.ipsw"),
            ("26.5.2", "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/140-25976/000BB0A6-045B-47FF-AE4E-D8BF722E24FD/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.5.2_23F84_Restore.ipsw"),
            ("26.6", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-57200/196D099E-2EA7-46E3-8BDA-A06BFBBB01C4/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.6_23G71_Restore.ipsw"),
            ("26.6.1", "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-74867/2D974F07-513F-4C4A-8B2D-816B22D03A24/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.6.1_23G83_Restore.ipsw"),
            ("26.6.2", "https://updates.cdn-apple.com/2026SummerFCS/c92fa0b5-4f21-4e74-8980-2926c7320a78/iPad17,1,iPad17,2,iPad17,3,iPad17,4_26.6.2_23G90_Restore.ipsw"),
            ("27.0", "https://updates.cdn-apple.com/2026FallFCS/3d6d90ea-e942-4a86-834f-939769d6e3f4/iPad17,1,iPad17,2,iPad17,3,iPad17,4_27.0_24A437_Restore.ipsw"),
            ("27.0.1", "https://updates.cdn-apple.com/2026FallFCS/6074e110-d48d-40c2-b0e8-b611520941a3/iPad17,1,iPad17,2,iPad17,3,iPad17,4_27.0.1_24A446_Restore.ipsw"),
        ]),
    ]

    /// The pairings for one guest device, oldest first: the iPhone17,3 list,
    /// or another model's releases with the cloudOS an iPhone17,3 of that
    /// release uses. A cellular iPad gets its Wi-Fi model's; an unknown device
    /// gets none.
    public static func pairings(for device: String) -> [VPhoneFirmwarePairing] {
        guard let guest = VPhoneGuestDevice.named(device) else { return [] }
        guard guest.presentsBoard else { return pairings }
        let releases = (iPhoneReleases + iPadReleases).first { $0.devices.contains(guest.productType) }?.releases ?? []
        return releases.map { release in
            let cloudOS = recommendedCloudOS(forVersion: release.version)
            return VPhoneFirmwarePairing(
                device: guest.productType,
                iosName: "\(guest.isPad ? "iPadOS" : "iOS") \(release.version)",
                iosURL: release.url,
                cloudosName: cloudOS.name,
                cloudosURL: cloudOS.url,
            )
        }
    }

    /// The cloudOS the iPhone pairings give a release of this version.
    static func recommendedCloudOS(forVersion version: String) -> VPhoneCloudOSOption {
        switch version.split(separator: ".").prefix(2).joined(separator: ".") {
        case "26.0", "26.1": VPhoneCloudOSOption(name: "cloudOS 26.1", url: cloud261)
        case "26.2": VPhoneCloudOSOption(name: "cloudOS 26.2", url: cloud262)
        case "26.3": VPhoneCloudOSOption(name: "cloudOS 26.3", url: cloud263)
        default: VPhoneCloudOSOption(name: "cloudOS 26.4", url: cloud264)
        }
    }

    /// Distinct cloudOS images (first-seen order) for the "choose the cloudOS" prompt.
    public static var cloudOSOptions: [VPhoneCloudOSOption] {
        var seen = Set<String>()
        var out: [VPhoneCloudOSOption] = []
        for p in pairings where seen.insert(p.cloudosName).inserted {
            out.append(VPhoneCloudOSOption(name: p.cloudosName, url: p.cloudosURL))
        }
        return out
    }

    /// JSON-friendly projection of the catalog: each build with its recommended
    /// cloudOS, for the iPhone and then per guest device.
    public static var report: VPhoneFirmwareCatalogReport {
        func entries(_ pairings: [VPhoneFirmwarePairing]) -> [VPhoneFirmwareCatalogReport.Entry] {
            pairings.map {
                .init(
                    ios: .init(name: $0.iosName, url: $0.iosURL),
                    recommendedCloudOS: .init(name: $0.cloudosName, url: $0.cloudosURL),
                )
            }
        }
        return VPhoneFirmwareCatalogReport(
            device: device,
            pairings: entries(pairings),
            devices: VPhoneGuestDevice.known.compactMap { guest in
                let pairings = pairings(for: guest.productType)
                guard !pairings.isEmpty else { return nil }
                return .init(
                    productType: guest.productType,
                    name: guest.productName,
                    family: guest.family.rawValue,
                    pairings: entries(pairings),
                )
            },
        )
    }
}

// MARK: - VPhoneFirmwareCatalogReport

/// Codable view of the firmware catalog for `fw catalog --json`.
///
/// `device` and `pairings` are the iPhone17,3 list that Launchpad releases
/// before iPad guests read; `devices` repeats it and adds every iPad.
public struct VPhoneFirmwareCatalogReport: Codable, Equatable, Sendable {
    public struct Firmware: Codable, Equatable, Sendable {
        public let name: String
        public let url: String
        public init(name: String, url: String) {
            self.name = name; self.url = url
        }
    }

    public struct Entry: Codable, Equatable, Sendable {
        public let ios: Firmware
        public let recommendedCloudOS: Firmware
        public init(ios: Firmware, recommendedCloudOS: Firmware) {
            self.ios = ios
            self.recommendedCloudOS = recommendedCloudOS
        }
    }

    /// One guest device and its pairings, oldest first.
    public struct Device: Codable, Equatable, Sendable {
        /// The product type `fw prepare --device` takes.
        public let productType: String
        /// The marketing name, such as `iPad mini (A17 Pro)`.
        public let name: String
        /// `iPhone` or `iPad`.
        public let family: String
        public let pairings: [Entry]
        public init(productType: String, name: String, family: String, pairings: [Entry]) {
            self.productType = productType
            self.name = name
            self.family = family
            self.pairings = pairings
        }
    }

    public let device: String
    public let pairings: [Entry]
    public let devices: [Device]

    public init(device: String, pairings: [Entry], devices: [Device]) {
        self.device = device
        self.pairings = pairings
        self.devices = devices
    }
}
