import Testing

@testable import DayPeek

@Test func rowActionsToggleShowsPencilWhenOn() {
    #expect(RowActionsToggle.symbol(isOn: true) == "pencil")
    #expect(RowActionsToggle.label(isOn: true) == "Hide row actions")
}

@Test func rowActionsToggleShowsSlashedPencilWhenOff() {
    #expect(RowActionsToggle.symbol(isOn: false) == "pencil.slash")
    #expect(RowActionsToggle.label(isOn: false) == "Show row actions")
}
