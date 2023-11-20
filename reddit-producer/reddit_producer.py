import json
import praw
from confluent_kafka import Producer

# Generates 4229 comments per minute
# 253,740 comments per hour
# 6,089,760 comments per day
# 182,692,800 comments per month

# If we do batches of 20 we can reduce it to 9,134,640 lambda invocations per month
# Or 304,488 per day

# Grab secrets
secrets = {}
with open("secrets.json", "r") as f:
    secrets = json.load(f)

REDDIT_CLIENT_ID = secrets["REDDIT_CLIENT_ID"]
REDDIT_CLIENT_SECRET = secrets["REDDIT_CLIENT_SECRET"]
KAFKA_TOPIC = "reddit-comments"

# Create reddit client
user_agent = "RedditSentimentMeter"
reddit = praw.Reddit(
    client_id=REDDIT_CLIENT_ID,
    client_secret=REDDIT_CLIENT_SECRET,
    user_agent=user_agent
)

# Create Kafka Producer client
conf = {
    "bootstrap.servers": secrets["kafka_server"],
    "security.protocol": "SASL_SSL",
    "sasl.mechanisms": "PLAIN",
    "sasl.username": secrets["kafka_username"],
    "sasl.password": secrets["kafka_password"]
}
producer = Producer(conf)

# Stream comments from Reddit
for comment in reddit.subreddit("all").stream.comments(skip_existing=True):
    text = str(comment.body)

    # Only produce messages that contain text
    if not text.isnumeric():
        # Convert comment to bytes
        producer.produce(KAFKA_TOPIC, value=bytes(text, 'utf-8'))
