import warnings
warnings.filterwarnings('ignore')

from sentence_transformers import SentenceTransformer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Load model ONCE outside the function
transformer_model = SentenceTransformer('all-MiniLM-L6-v2')

def calculate_hybrid_similarity(cv_summary: str, job_summary: str) -> float:
    """
    Calculate hybrid similarity between CV summary and Job summary.
    TF-IDF: 10%, Transformer: 90%
    Returns: score between 0 and 100.
    """
    if not cv_summary or not job_summary:
        return 0.0
    
    # 1. TF-IDF (10%)
    vectorizer = TfidfVectorizer(stop_words='english')
    tfidf_matrix = vectorizer.fit_transform([cv_summary, job_summary])
    tfidf_score = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])[0][0]
    
    # 2. Transformer (90%)
    cv_emb = transformer_model.encode(cv_summary)
    job_emb = transformer_model.encode(job_summary)
    transformer_score = cosine_similarity([cv_emb], [job_emb])[0][0]
    
    # 3. Combine: 10% TF-IDF + 90% Transformer
    hybrid_score = (tfidf_score * 0.1) + (transformer_score * 0.9)
    
    return min(hybrid_score * 100, 100.0)