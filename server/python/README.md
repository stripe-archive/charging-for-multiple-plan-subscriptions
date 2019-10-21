# Stripe Billing charging for subscriptions

## Requirements

- Python 3
- [Configured .env file](../README.md)

## How to run

1. Create and activate a new virtual environment

```
python3 -m venv /path/to/new/virtual/environment
source /path/to/new/virtual/environment/venv/bin/activate
```

**TIP**: create the virtualenv in it's own directory, to keep it's contents separate from the rest of your code. 
A common convention is to create it locally in your project, but hidden and excluded in .gitignore. 

Ex: ```server/python/.virtualenv```

A number of tools use the convention of storing named virtualenvs in a subdirectory of the user's home dir. 

Ex: ```$HOME/.virtualenvs/stripe-samples```


2. Install dependencies

```
pip install -r requirements.txt
```

3. Export and run the application

```
export FLASK_APP=server.py
python3 -m flask run --port=4242
```

4. Go to `localhost:4242` in your browser to see the demo
