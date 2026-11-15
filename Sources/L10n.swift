import Foundation

func L(_ vi: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("vi") == true ? vi : en
}
