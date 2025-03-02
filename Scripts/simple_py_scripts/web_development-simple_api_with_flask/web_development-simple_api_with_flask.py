from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def hello() -> jsonify:
    """Returns a simple JSON response via Flask."""
    return jsonify({'message': 'Hello, Flask!'})

if __name__ == '__main__':
    app.run(debug=True)
