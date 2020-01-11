from flask import Flask

app = Flask(__name__)

@app.route("/ping")
def home():
    return "pong"

if __name__ == "__main__":
    app.run(debug=True,host='0.0.0.0')
    

