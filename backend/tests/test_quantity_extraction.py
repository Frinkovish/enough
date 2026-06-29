from app.integrations.quantity_extraction import extract_amount_in_unit, format_number


def test_extracts_direct_unit_match() -> None:
    assert extract_amount_in_unit("Read 4 pages", "pages") == 4.0


def test_extracts_direct_unit_match_singular_vs_plural() -> None:
    assert extract_amount_in_unit("Run 1 km", "km") == 1.0


def test_extracts_spelled_out_number_with_singular_unit() -> None:
    assert extract_amount_in_unit("Practice padel serves for one session", "sessions") == 1.0


def test_converts_minutes_to_hours() -> None:
    assert extract_amount_in_unit("Study DBT for 15 minutes", "hours") == 0.25


def test_converts_hours_to_minutes() -> None:
    assert extract_amount_in_unit("Meditate for 1 hour", "minutes") == 60.0


def test_returns_none_when_no_quantity_stated() -> None:
    assert extract_amount_in_unit("Tidy one small space", "pages") is None


def test_returns_none_when_unit_does_not_match_and_is_not_a_time_conversion() -> None:
    assert extract_amount_in_unit("Box-breathing, 4 rounds", "pages") is None


def test_returns_none_for_unrelated_number_unit_pair() -> None:
    # "5 senses" shouldn't satisfy a "sessions" goal just because both
    # start with the same letters.
    assert extract_amount_in_unit("Five senses check-in, 5 senses noticed", "sessions") is None


def test_format_number_strips_trailing_zero() -> None:
    assert format_number(5.0) == "5"
    assert format_number(0.25) == "0.25"
    assert format_number(1.5) == "1.5"
