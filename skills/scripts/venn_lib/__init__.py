__version__ = "0.10dev1"

import os

if os.environ.get("__IN-SETUP", None) != "1":
    from .drawvenn import (
        get_labels,
        venn,
        flower_plot
    )

    __all__ = [
        "get_labels",
        "venn",
        "flower_plot"
    ]
