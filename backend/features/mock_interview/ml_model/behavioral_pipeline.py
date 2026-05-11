# ============================================
# COMPLETE INFERENCE PIPELINE - ORIGINAL (NO CALIBRATION)
# Extracts personality predictions and metrics
# Outputs JSON file for AI analysis
# ============================================

import os
from io import BytesIO
from pathlib import Path
import json
import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
import subprocess
import cv2
from typing import Dict, Optional, List, Any
import warnings
warnings.filterwarnings("ignore")

# ============================================
# CONFIGURATION
# ============================================

class Config:
    BASE_DIR = Path(__file__).resolve().parent.parent
    ASSETS_DIR = BASE_DIR / "behavioral_pipeline_assets"

    # Model paths
    VISUAL_CKPT = str(ASSETS_DIR / "best_visual_model.pth")
    AUDIO_CKPT = str(ASSETS_DIR / "best_audio_model.pth")
    TEXT_CKPT = str(ASSETS_DIR / "best_text_fasttext_tuned.pth")
    STAGE2_CKPT = str(ASSETS_DIR / "best_stage2.pth")
    STAGE3_CKPT = str(ASSETS_DIR / "best_cross_siamese.pth")
    STAGE4_CKPT = str(ASSETS_DIR / "best_final_stage4.pth")
    VOCAB_PATH = str(ASSETS_DIR / "vocab.json")
    AUDIO_STATS_PATH = str(ASSETS_DIR / "audio_stats.npz")

    # Processing parameters (NO CALIBRATION)
    MAX_FRAMES = 6
    MAX_TEXT_LEN = 80
    CROP_SIZE = 128
    RESIZE_SIZE = 140
    
    TRAIT_DISPLAY = ["Extraversion", "Agreeableness", "Conscientiousness", "Neuroticism", "Openness"]

config = Config()

# ============================================
# MODEL DEFINITIONS
# ============================================

class SiameseProjection(nn.Module):
    def __init__(self, input_dim=256, embedding_dim=128, dropout=0.3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, 256), nn.LayerNorm(256), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(256, 128), nn.LayerNorm(128), nn.ReLU(),
            nn.Linear(128, embedding_dim),
        )
    def forward(self, x): return self.net(x)

class MultiModalSiamese(nn.Module):
    def __init__(self):
        super().__init__()
        self.visual_proj = SiameseProjection()
        self.audio_proj = SiameseProjection()
        self.text_proj = SiameseProjection()
    def forward(self, vis, aud, txt):
        return self.visual_proj(vis), self.audio_proj(aud), self.text_proj(txt)

class FinalFusionHead(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(896, 512), nn.ReLU(), nn.Dropout(0.3),
            nn.Linear(512, 256), nn.ReLU(), nn.Dropout(0.3),
            nn.Linear(256, 5), nn.Sigmoid()
        )
    def forward(self, x): return self.net(x)

class VisualSubnetwork(nn.Module):
    def __init__(self):
        super().__init__()
        from torchvision import models
        resnet = models.resnet50(weights=None)
        self.backbone = nn.Sequential(*list(resnet.children())[:-1])
        self.fc_head = nn.Sequential(
            nn.Linear(2048, 512), nn.ReLU(), nn.Dropout(0.5),
            nn.Linear(512, 256), nn.ReLU()
        )
        self.regression_head = nn.Linear(256, 5)
    def forward(self, x):
        bs, n, c, h, w = x.shape
        x = x.view(bs * n, c, h, w)
        f = self.backbone(x).view(bs * n, -1).view(bs, n, -1).mean(1)
        return self.fc_head(f), torch.sigmoid(self.regression_head(self.fc_head(f)))

class AcousticSubnetwork(nn.Module):
    def __init__(self, input_dim=88):
        super().__init__()
        self.backbone = nn.Sequential(
            nn.Linear(input_dim, 128), nn.ReLU(), nn.Dropout(0.3),
            nn.Linear(128, 256), nn.ReLU(), nn.Dropout(0.3),
        )
        self.regression_head = nn.Linear(256, 5)
    def forward(self, x):
        h = self.backbone(x)
        return h, torch.sigmoid(self.regression_head(h))

class TextSubnetwork(nn.Module):
    def __init__(self, vocab_size):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, 300, padding_idx=0)
        self.bigru = nn.GRU(300, 256, 1, batch_first=True, bidirectional=True)
        self.layer_norm = nn.LayerNorm(512)
        self.attention = nn.Linear(512, 1)
        self.fc = nn.Linear(512, 256)
        self.dropout = nn.Dropout(0.5)
        self.regression_head = nn.Linear(256, 5)
    def forward(self, x):
        e = self.dropout(self.embedding(x))
        g, _ = self.bigru(e)
        g = self.layer_norm(g)
        a = self.attention(g).squeeze(-1)
        a = a.masked_fill((x == 0), -1e9)
        w = torch.softmax(a, dim=1).unsqueeze(-1)
        o = torch.sum(w * g, dim=1)
        o = self.dropout(self.fc(o))
        return o, torch.sigmoid(self.regression_head(o))

def build_fusion_head():
    return nn.Sequential(
        nn.Linear(768, 512), nn.ReLU(), nn.Dropout(0.5),
        nn.Linear(512, 5), nn.Sigmoid()
    )

# ============================================
# VIDEO FRAME EXTRACTION
# ============================================

def extract_video_frames(video_path, device):
    import torchvision.transforms.functional as TF
    
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    indices = np.linspace(0, total_frames - 1, config.MAX_FRAMES, dtype=int).tolist()
    
    frames_list = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if ret:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frames_list.append(frame)
        else:
            frames_list.append(np.zeros((224, 224, 3), dtype=np.uint8))
    cap.release()
    
    frames = torch.from_numpy(np.stack(frames_list)).float() / 255.0
    frames = frames.permute(0, 3, 1, 2)
    frames = TF.resize(frames, [config.RESIZE_SIZE, config.RESIZE_SIZE])
    frames = TF.center_crop(frames, [config.CROP_SIZE, config.CROP_SIZE])
    frames = TF.normalize(frames, mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
    return frames.unsqueeze(0).to(device)

# ============================================
# AUDIO FEATURE EXTRACTION
# ============================================

def extract_audio_features(video_path, device, smile, audio_mins, audio_denom):
    cmd = ["ffmpeg", "-v", "error", "-i", video_path, "-ac", "1", "-ar", "44100", "-f", "f32le", "-"]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(f"FFmpeg failed")
    audio_data = np.frombuffer(result.stdout, dtype=np.float32)
    if len(audio_data) == 0:
        raise RuntimeError("No audio data")
    feat_df = smile.process_signal(audio_data, 44100)
    audio_feat = feat_df.iloc[0].to_numpy(dtype=np.float32)
    audio_feat = (audio_feat - audio_mins) / (audio_denom + 1e-8)
    return torch.from_numpy(audio_feat).float().unsqueeze(0).to(device)

# ============================================
# TEXT PREPROCESSING
# ============================================

def preprocess_text(text, vocab, nlp, max_len=80):
    if not text:
        return torch.zeros(1, max_len, dtype=torch.long)
    FILLERS = {"um", "uh", "ah", "eh", "oh", "mm", "hmm", "like", "you know"}
    doc = nlp(text.lower())
    tokens = []
    for tok in doc:
        if not tok.is_alpha:
            continue
        if tok.text in FILLERS:
            continue
        tokens.append(tok.lemma_)
    ids = [vocab.get(t, vocab.get("<UNK>", 1)) for t in tokens[:max_len]]
    ids += [vocab.get("<PAD>", 0)] * (max_len - len(ids))
    return torch.tensor([ids], dtype=torch.long)

# ============================================
# LOAD CHECKPOINTS
# ============================================

def load_checkpoint(model, path, device):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Checkpoint not found: {path}")
    state_dict = torch.load(path, map_location=device)
    if any(k.startswith("_orig_mod.") for k in state_dict.keys()):
        state_dict = {k.replace("_orig_mod.", "", 1): v for k, v in state_dict.items()}
    model.load_state_dict(state_dict, strict=True)
    model.to(device)
    model.eval()
    return model

def load_vocab(path):
    with open(path, 'r') as f:
        return json.load(f)

# ============================================
# METRICS EXTRACTION
# ============================================

def extract_visual_metrics(video_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames == 0:
        return None
    face_positions, head_movements, smile_scores, eye_contact_frames = [], [], [], 0
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    eye_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_eye.xml')
    prev_face_center = None
    sample_step = max(1, total_frames // 100)
    processed_frames = 0
    for frame_idx in range(0, total_frames, sample_step):
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
        ret, frame = cap.read()
        if not ret:
            continue
        processed_frames += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.3, 5)
        if len(faces) > 0:
            x, y, w, h = faces[0]
            face_center = (x + w//2, y + h//2)
            face_positions.append(face_center)
            if prev_face_center is not None:
                movement = np.sqrt((face_center[0] - prev_face_center[0])**2 + (face_center[1] - prev_face_center[1])**2)
                head_movements.append(movement)
            prev_face_center = face_center
            roi_gray = gray[y:y+h, x:x+w]
            eyes = eye_cascade.detectMultiScale(roi_gray, 1.1, 5)
            if len(eyes) >= 2:
                eye_contact_frames += 1
            mouth_y = y + int(h * 0.7)
            mouth_h = int(h * 0.2)
            if mouth_y + mouth_h < frame.shape[0]:
                mouth_region = gray[mouth_y:mouth_y+mouth_h, x:x+w]
                avg_intensity = np.mean(mouth_region)
                smile_score = 1.0 if avg_intensity > 180 else avg_intensity / 180
                smile_scores.append(smile_score)
        if processed_frames >= 200:
            break
    cap.release()
    eye_contact_pct = (eye_contact_frames / processed_frames * 100) if processed_frames > 0 else 0
    head_stability = 1.0 - (np.mean(head_movements) / 100.0) if head_movements else 0.5
    smile_freq = np.mean(smile_scores) if smile_scores else 0.3
    return {
        "eye_contact_percentage": round(eye_contact_pct, 1),
        "head_stability_score": round(np.clip(head_stability, 0, 1), 3),
        "smile_frequency": round(smile_freq, 3),
        "face_visibility": round(len(face_positions) / processed_frames if processed_frames > 0 else 0, 3),
        "head_movement_variance": round(np.std(head_movements) if head_movements else 0, 2)
    }

def extract_audio_metrics(video_path):
    try:
        cmd = ["ffmpeg", "-v", "error", "-i", video_path, "-ac", "1", "-ar", "16000", "-f", "wav", "-"]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0 or not result.stdout:
            return None

        import soundfile as sf
        audio, sr = sf.read(BytesIO(result.stdout))
        if len(audio) == 0:
            return None
        duration = len(audio) / sr
        energy = np.abs(audio)
        threshold = np.percentile(energy, 30)
        speech_frames = energy > threshold
        speech_segments = np.diff(np.concatenate(([0], speech_frames.astype(int), [0])))
        speech_starts = np.where(speech_segments == 1)[0]
        speech_ends = np.where(speech_segments == -1)[0]
        if len(audio) > sr:
            zcr = np.mean(np.diff((audio > 0).astype(int)))
            voice_variation = min(1.0, zcr * 10)
        else:
            voice_variation = 0.5
        if len(speech_starts) > 1:
            pauses = speech_starts[1:] - speech_ends[:-1]
            avg_pause = np.mean(pauses) / sr if len(pauses) > 0 else 0
            long_pause_count = len([p for p in pauses if p / sr > 0.5])
        else:
            avg_pause = 0
            long_pause_count = 0
        speaking_rate = (len(audio) / sr) * 120 / duration if duration > 0 else 0
        volume_consistency = 1.0 - np.std(energy) / (np.mean(energy) + 1e-5)
        volume_consistency = max(0, min(1, volume_consistency))
        return {
            "speaking_rate_wpm": round(speaking_rate, 1),
            "volume_consistency": round(volume_consistency, 3),
            "voice_variation_score": round(voice_variation, 3),
            "filler_words_per_minute": 0,
            "avg_pause_duration": round(avg_pause, 2),
            "long_pause_count": long_pause_count,
            "speech_clarity": round(1.0 - (long_pause_count / max(1, len(speech_starts))), 3)
        }
    except Exception:
        return None

def extract_text_metrics(transcript):
    if not transcript:
        return None
    sentences = [s.strip() for s in transcript.split('.') if s.strip()]
    words = transcript.split()
    word_count = len(words)
    avg_sentence_len = word_count / max(1, len(sentences))
    unique_words = set(w.lower() for w in words)
    lexical_diversity = len(unique_words) / max(1, word_count)
    confidence_words = ["absolutely", "definitely", "certainly", "confident", "sure", "believe", "know", "guarantee"]
    confidence_count = sum(1 for w in words if w.lower() in confidence_words)
    confidence_score = min(1.0, confidence_count / max(1, word_count) * 20)
    filler_words_set = {"um", "uh", "ah", "eh", "oh", "like", "you know", "actually", "basically", "literally", "so", "well"}
    filler_count = sum(1 for w in words if w.lower() in filler_words_set)
    filler_rate = filler_count / max(1, word_count) * 100
    long_words = [w for w in words if len(w) > 6]
    complexity_score = len(long_words) / max(1, word_count)
    has_intro = any(w.lower() in ["first", "to begin", "initially", "i think"] for w in words[:20])
    has_conclusion = any(w.lower() in ["finally", "in conclusion", "therefore", "so"] for w in words[-20:])
    structure_score = (has_intro + has_conclusion) / 2
    clarity_score = max(0, 1.0 - (filler_rate / 100) - (avg_sentence_len / 200))
    return {
        "word_count": word_count,
        "avg_sentence_length": round(avg_sentence_len, 1),
        "lexical_diversity": round(lexical_diversity, 3),
        "confidence_score": round(confidence_score, 3),
        "filler_word_rate": round(filler_rate, 1),
        "complexity_score": round(complexity_score, 3),
        "structure_score": round(structure_score, 3),
        "clarity_score": round(clarity_score, 3)
    }

# ============================================
# LOAD MODELS FUNCTION
# ============================================

def load_all_models(device):
    print(f"\n Loading models on {device}...")
    
    vocab = load_vocab(config.VOCAB_PATH)
    print(f" Vocab: {len(vocab)} words")
    
    import spacy
    try:
        nlp = spacy.load("en_core_web_sm", disable=['parser', 'ner'])
    except:
        os.system("python -m spacy download en_core_web_sm --quiet")
        nlp = spacy.load("en_core_web_sm", disable=['parser', 'ner'])
    print(" Spacy loaded")
    
    import opensmile
    smile = opensmile.Smile(
        feature_set=opensmile.FeatureSet.eGeMAPSv02,
        feature_level=opensmile.FeatureLevel.Functionals,
    )
    print(" OpenSMILE loaded")
    
    stats = np.load(config.AUDIO_STATS_PATH)
    audio_mins, audio_denom = stats['mins'], stats['denom']
    print(" Audio stats loaded")
    
    visual = load_checkpoint(VisualSubnetwork(), config.VISUAL_CKPT, device)
    audio = load_checkpoint(AcousticSubnetwork(88), config.AUDIO_CKPT, device)
    text = load_checkpoint(TextSubnetwork(len(vocab)), config.TEXT_CKPT, device)
    baseline = load_checkpoint(build_fusion_head(), config.STAGE2_CKPT, device)
    siamese = load_checkpoint(MultiModalSiamese(), config.STAGE3_CKPT, device)
    final = load_checkpoint(FinalFusionHead(), config.STAGE4_CKPT, device)
    
    print("🎉 ALL MODELS LOADED!\n")
    return vocab, nlp, smile, audio_mins, audio_denom, visual, audio, text, baseline, siamese, final

# ============================================
# PREDICT FUNCTION
# ============================================

def predict_video(
    video_path,
    visual,
    audio,
    text,
    baseline,
    siamese,
    final,
    vocab,
    nlp,
    smile,
    audio_mins,
    audio_denom,
    device,
    transcript_text: Optional[str] = None,
    transcript_words: Optional[List[Dict[str, Any]]] = None,
):
    transcript_text = transcript_text or ""
    transcript_words = transcript_words or []
    
    print(" Extracting video frames...")
    frames = extract_video_frames(video_path, device)
    
    print(" Extracting audio features...")
    audio_tensor = extract_audio_features(video_path, device, smile, audio_mins, audio_denom)
    
    print(" Processing text...")
    text_tensor = preprocess_text(transcript_text or "", vocab, nlp, config.MAX_TEXT_LEN).to(device)
    
    print(" Running inference...")
    with torch.no_grad():
        hV, _ = visual(frames)
        hA, _ = audio(audio_tensor)
        hT, _ = text(text_tensor)
        combined = torch.cat([hA, hV, hT], dim=1)
        m1_hidden = baseline[0](combined)
        eV, eA, eT = siamese(hV, hA, hT)
        eV, eA, eT = F.normalize(eV, dim=1), F.normalize(eA, dim=1), F.normalize(eT, dim=1)
        fused = torch.cat([m1_hidden, eV, eA, eT], dim=1)
        predictions = final(fused)
    
    preds = {config.TRAIT_DISPLAY[i]: float(predictions[0][i]) for i in range(5)}
    return preds, transcript_text, transcript_words
