from rapidfuzz import fuzz


def compute_match_score(a: str, b: str) -> int:
    """Compute fuzzy match score between two strings (0-100)."""
    if not a or not b:
        return 0
    a = a.strip().lower()
    b = b.strip().lower()
    return int(
        max(
            fuzz.token_sort_ratio(a, b),
            fuzz.partial_ratio(a, b),
            fuzz.token_set_ratio(a, b),
        )
    )
