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
        return jsonify({"error": "الوصف لا يمكن أن يكون فارغًا"}), 400
    try:
        model = genai.GenerativeModel("models/imagegeneration")
        response = model.generate_content(prompt)
        if response and response.candidates:
            base64_image = response.candidates[0].content.parts[0].inline_data.data
            return jsonify({"image_base64": base64_image})
        else:
            return jsonify({"error": "لم يتم توليد صورة"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/")
def serve_index():
    return send_from_directory(app.static_folder, "index.html")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
