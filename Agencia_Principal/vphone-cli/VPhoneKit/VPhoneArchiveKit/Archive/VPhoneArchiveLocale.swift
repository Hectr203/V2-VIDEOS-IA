import Foundation

/// Runs one synchronous libarchive session with a UTF-8 LC_CTYPE on the
/// calling thread.
///
/// libarchive converts member names and link targets between the archive's
/// charset and the thread's LC_CTYPE codeset. Nothing in vphone calls
/// setlocale(3), so every process — vphone-cli from a terminal, as a child of
/// Launchpad, or under its root helper — runs in "C", whose codeset is
/// US-ASCII. There a zip entry with the UTF-8 flag or a pax path with
/// non-ASCII characters comes back with a NULL pathname and ARCHIVE_WARN, and
/// the pax writer refuses the header outright.
///
/// uselocale(3) scopes the change to this thread and to `body`; setlocale(3)
/// would change it for every thread in the process. The other categories are
/// copied from the thread's current locale, so only LC_CTYPE changes.
func withArchiveLocale<T>(_ body: () throws -> T) rethrows -> T {
    guard let base = duplocale(uselocale(nil)) else {
        return try body()
    }
    guard let locale = newlocale(LC_CTYPE_MASK, "UTF-8", base) else {
        // On failure newlocale leaves `base` to the caller. Without a UTF-8
        // locale there is nothing better to do than the old behaviour.
        freelocale(base)
        return try body()
    }
    let previous = uselocale(locale)
    defer {
        uselocale(previous)
        freelocale(locale)
    }
    return try body()
}
