"""
Pagination utilities.
Strictly for internal use to normalize offset/limit calculations.
"""

from typing import Tuple


def calculate_offset(page: int, page_size: int) -> int:
    """
    Calculate database offset from page number and page size.
    Page numbers are 1-based.
    """
    if page < 1:
        page = 1
    return (page - 1) * page_size


def get_pagination_params(
    skip: int = 0, limit: int = 100, page: int = None, page_size: int = None
) -> Tuple[int, int]:
    """
    Normalize various pagination inputs to (offset, limit).
    Prioritizes page/page_size if provided and non-None.
    """
    if page is not None and page_size is not None:
        return calculate_offset(page, page_size), page_size
    return skip, limit
