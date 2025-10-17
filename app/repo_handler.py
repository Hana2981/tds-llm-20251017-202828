import os
from github import Github
from dotenv import load_dotenv

load_dotenv()
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_USER = os.getenv("GITHUB_USER")

def create_github_repo(name: str, description="Auto-generated repo"):
    g = Github(GITHUB_TOKEN)
    user = g.get_user()
    repo = user.create_repo(name=name, description=description)
    return repo.html_url
