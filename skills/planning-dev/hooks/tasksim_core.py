# tasksim.py·prsim.py가 함께 쓰는 순위 계산. 수집은 각 스크립트가 하고, 여기서는 순위만 낸다.
#
# 문서 전체를 Kiwi로 형태소 분석해 TF-IDF로 벡터화하고,
# 쿼리와 코사인 유사도가 높은 순으로 낸다.
#
# attention 기반 임베딩(문단 평균 풀링)도 시도해봤으나, 구체적 키워드 신호가
# 문서 전체 문체에 묻혀 변별력이 떨어지고 속도도 느려서 TF-IDF로 되돌렸다.
#
# kiwipiepy·scikit-learn·scipy가 없으면 분석을 멈추지 않고, 없다는 사실만 알리고 끝낸다.

import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

TOP_N = 8


def fail(msg: str):
    print(msg)
    sys.exit(0)  # 분석을 멈추게 하지 않는다. 신호가 없다는 것도 결과다.


try:
    from kiwipiepy import Kiwi
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
except ImportError as e:
    fail(f"필요한 라이브러리가 없다({e.name}) — 유사 태스크 검색을 건너뛴다.")

CODE_BLOCK = re.compile(r"```[\s\S]*?```")
KEEP_TAGS = {"NNG", "NNP", "SL"}  # 일반명사·고유명사·외국어(영문 식별자)


def rank(docs: list[str], query: str) -> list[tuple[int, float]]:
    """유사도가 0보다 큰 문서를 (인덱스, 유사도)로, 높은 순서대로 TOP_N개까지 돌려준다."""
    kiwi = Kiwi()

    def tokenize(text: str) -> str:
        text = CODE_BLOCK.sub(" ", text)
        tokens = [t.form for t in kiwi.tokenize(text) if t.tag in KEEP_TAGS and len(t.form) > 1]
        return " ".join(tokens)

    vec = TfidfVectorizer(min_df=1)
    X = vec.fit_transform([tokenize(d) for d in docs])
    sims = cosine_similarity(vec.transform([tokenize(query)]), X).ravel()
    order = sims.argsort()[::-1]
    return [(int(i), float(sims[i])) for i in order[:TOP_N] if sims[i] > 0]
