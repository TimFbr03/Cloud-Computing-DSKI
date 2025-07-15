# app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

# Hilfsfunktion für Addition
def add_numbers(a, b):
    return a + b

@app.route('/')
def hello():
    return "Welcome to the Kubernetes Test API"

# Neue API-Route zum Addieren von zwei Zahlen
@app.route('/add', methods=['GET'])
def add():
    try:
        a = float(request.args.get('a'))
        b = float(request.args.get('b')) 
        result = add_numbers(a, b)
        return jsonify({
            'a': a,
            'b': b,
            'result': result
            })
    except (TypeError, ValueError):
        return jsonify({'error': 'Bitte gueltige Zahlen angeben, z.B. /add?a=3&b=4'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
