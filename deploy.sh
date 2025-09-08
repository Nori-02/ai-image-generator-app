#!/bin/bash

set -e

echo "🚀 بدء إعداد الخادم..."

# 1. تحديث النظام وتثبيت الأدوات الأساسية
echo "🔧 تثبيت الأدوات الأساسية..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl

# 2. تثبيت Docker إذا لم يكن موجوداً
if ! command -v docker &> /dev/null; then
  echo "🐳 تثبيت Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  sudo usermod -aG docker $USER
fi

# 3. تثبيت Docker Compose إذا لم يكن موجوداً
if ! command -v docker-compose &> /dev/null; then
  echo "🧩 تثبيت Docker Compose..."
  DOCKER_COMPOSE_VERSION="2.24.6"
  sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# 4. تجهيز مشروع ai-image-generator
PROJECT_DIR="ai-image-generator"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "📁 إنشاء مجلد المشروع: $PROJECT_DIR"
  mkdir "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# 5. إنشاء ملفات المشروع إذا لم تكن موجودة
if [ ! -f "app.py" ]; then
  echo "📝 إنشاء الملفات الأساسية..."

  # ملف البيئة .env
  cat > .env <<EOF
# ضع مفتاح Gemini API الخاص بك هنا
GEMINI_API_KEY=your-api-key-here
EOF

  # ملف المتطلبات مع إضافة gunicorn
  cat > requirements.txt <<EOF
flask
flask-cors
python-dotenv
google-genai
gunicorn
EOF

  # ملف Dockerfile مع استخدام gunicorn كأمر تشغيل
  cat > Dockerfile <<EOF
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install --upgrade pip && pip install -r requirements.txt
ENV PORT=8080
EXPOSE 8080
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:\$PORT"]
EOF

  # ملف docker-compose.yml
  cat > docker-compose.yml <<EOF
version: "3.9"
services:
  web:
    build: .
    ports:
      - "80:8080"
    environment:
      - GEMINI_API_KEY=\${GEMINI_API_KEY}
    volumes:
      - .:/app
    restart: always
EOF

  # مجلد static وملف index.html
  mkdir -p static
  cat > static/index.html <<EOF
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>AI Image Generator</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 text-gray-900">
  <div class="max-w-xl mx-auto p-4">
    <h1 class="text-2xl font-bold mb-4">توليد صورة</h1>
    <textarea id="prompt" class="w-full p-3 border rounded mb-4" placeholder="صف الصورة..."></textarea>
    <button id="generateButton" class="w-full bg-blue-600 text-white py-2 rounded">توليد الصورة</button>
    <div id="imageContainer" class="mt-6 hidden">
      <img id="generatedImage" class="w-full rounded shadow" />
    </div>
  </div>
  <script>
    document.getElementById("generateButton").addEventListener("click", async () => {
      const prompt = document.getElementById("prompt").value;
      const res = await fetch("/generate-image", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt })
      });
      const data = await res.json();
      if (data.image_base64) {
        document.getElementById("generatedImage").src = "data:image/png;base64," + data.image_base64;
        document.getElementById("imageContainer").classList.remove("hidden");
      } else {
        alert("فشل التوليد: " + (data.error || "خطأ غير معروف"));
      }
    });
  </script>
</body>
</html>
EOF

  # ملف التطبيق app.py
  cat > app.py <<EOF
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
import os
from google import genai

load_dotenv()
app = Flask(__name__, static_folder="static")
CORS(app)
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise RuntimeError("GEMINI_API_KEY not set in environment variables.")
genai.configure(api_key=api_key)

@app.route("/generate-image", methods=["POST"])
def generate_image():
    prompt = request.json.get("prompt", "")
    if not prompt.strip():
        return jsonify({"error": "Prompt must not be empty."}), 400
    try:
        model = genai.GenerativeModel("models/imagegeneration")
        response = model.generate_content(prompt)
        if response and response.candidates:
            image = response.candidates[0].content.parts[0].inline_data.data
            return jsonify({"image_base64": image})
        else:
            return jsonify({"error": "لم يتم توليد صورة"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/")
def serve_index():
    return send_from_directory(app.static_folder, "index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

fi

# 6. تشغيل التطبيق باستخدام Docker Compose
echo "🚀 تشغيل التطبيق باستخدام Docker Compose..."
docker-compose up --build -d

echo "🎉 تم تشغيل الموقع! تحقق من http://<عنوان_IP_الخادم>"
