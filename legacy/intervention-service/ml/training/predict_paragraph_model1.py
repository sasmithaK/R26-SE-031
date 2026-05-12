# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INF = ROOT / "inference"
if str(INF) not in sys.path:
    sys.path.insert(0, str(INF))

from model1_inference import Model1Predictor, infer_error_type_hint, tokenize_sinhala_text  # noqa: E402


def main() -> None:
    text = (
        "ඇපල් කියන්නේ රවුම් සහ රසවත් පළතුරක් 🍎. ඒවා රතු, කොළ හෝ කහ පාටවලින් තිබේ. "
        "ඇපල් මිහිරි සහ රසවත් වන අතර අපේ සෞඛ්‍යයට හොඳයි. අපි දිනපතා ඇපල් කෑමෙන් ශක්තිමත් "
        "වෙන්න පුළුවන්. ඇපල් ගස්වල වැවෙයි, ඒවා ඇතුළේ කුඩා බීජ තියෙනවා"
    )

    p = Model1Predictor(ROOT / "model1")
    words = tokenize_sinhala_text(text)

    for w in words:
        r = p.predict_one(w)
        diff = int(r.get("difficulty_pred") or 0)
        et = infer_error_type_hint(str(r.get("error_type_pred") or "none"))
        print(f"{w}\t{diff}\t{et if et is not None else 'none'}")

    print("\nTotal words:", len(words))


if __name__ == "__main__":
    main()

