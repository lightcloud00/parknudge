import XCTest
@testable import ParkNudge

final class CSVAndMoneyTests: XCTestCase {
    func testRFC4180Escaping() {
        XCTAssertEqual(ParkingCSVEncoder.escape("plain"), "plain")
        XCTAssertEqual(ParkingCSVEncoder.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(ParkingCSVEncoder.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(ParkingCSVEncoder.escape("a\nb"), "\"a\nb\"")
    }

    func testCSVHasCRLFAndOmitsPhotoPath() {
        let session = TestFixtures.session(
            endedAt: TestFixtures.date.addingTimeInterval(3_600),
            photoRelativePath: "Photos/private.jpg"
        )
        let csv = ParkingCSVEncoder.encode([session])

        XCTAssertTrue(csv.hasSuffix("\r\n"))
        XCTAssertTrue(csv.contains("paid_amount_minor,currency_code"))
        XCTAssertTrue(csv.contains("1250,USD"))
        XCTAssertFalse(csv.contains("private.jpg"))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 3)
    }

    func testMoneyParsingUsesLocaleSeparatorAndBankersRounding() {
        XCTAssertEqual(
            MoneyParser.minorUnits(
                from: "12.50",
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            ),
            1_250
        )
        XCTAssertEqual(
            MoneyParser.minorUnits(
                from: "12,50",
                currencyCode: "EUR",
                locale: Locale(identifier: "de_DE")
            ),
            1_250
        )
        XCTAssertEqual(
            MoneyParser.minorUnits(
                from: "1.005",
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            ),
            100
        )
        XCTAssertNil(MoneyParser.minorUnits(
            from: "-1",
            currencyCode: "USD",
            locale: Locale(identifier: "en_US")
        ))
    }

    func testMoneyParsingUsesCurrencySpecificMinorUnits() {
        XCTAssertEqual(
            MoneyParser.minorUnits(
                from: "1250",
                currencyCode: "JPY",
                locale: Locale(identifier: "ja_JP")
            ),
            1_250
        )
        XCTAssertEqual(
            MoneyParser.minorUnits(
                from: "1.234",
                currencyCode: "BHD",
                locale: Locale(identifier: "en_US")
            ),
            1_234
        )
        XCTAssertEqual(
            ParkNudgeFormatting.decimalMoneyText(
                minorUnits: 1_234,
                currencyCode: "BHD",
                locale: Locale(identifier: "en_US")
            ),
            "1.234"
        )
    }
}
