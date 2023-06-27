import { ComprehendClient, DetectSentimentCommand } from "@aws-sdk/client-comprehend";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (event) => {
    const region = 'us-west-2';

    // Create Comprehend client
    const comprehendClient = new ComprehendClient({ region: region });

    // Create DynamoDB client
    const dynamoDBClient = new DynamoDBClient({ region: region });
    const documentClient = DynamoDBDocumentClient.from(dynamoDBClient);

    const todaysDate = getTodaysDateFormatted();

    // Stores a list of promises that will be resolved later
    let promises = [];

    // Counter for number of negative and positive sentiments detected
    let numPositive = 0;
    let numNegative = 0;

    // Use AWS Comprehend to detect sentiment
    const detectSentiment = async (input) => {
        // Text sent is base64 encoded. Decode it.
        const base64Text = input.payload.value.toString();
        const decodedText = Buffer.from(base64Text, 'base64').toString('utf-8');
    
        const comprehendParams = {
            LanguageCode: 'en',
            Text: decodedText
        };
    
        // Extract sentiment from Reddit comment
        const sentimentCommand = new DetectSentimentCommand(comprehendParams);
        const data = await comprehendClient.send(sentimentCommand);
        // Possible values: positive | negative | neutral | mixed
        const detectedSentiment = data.Sentiment.toLowerCase();

        // If sentiment is negative or mixed, increment negative count
        if (detectedSentiment === 'negative' || detectedSentiment === 'mixed') {
            numNegative++;
        } else {
            // If sentiment is positive or neutral, increment positive count
            numPositive++;
        }
    }
    
    // Process batched events from Kafka
    for (let i = 0; i < event.length; i++) {
        // Asynchronously process each event
        promises.push(detectSentiment(event[0]));
    }

    // Wait for all asynchronous processes to finish
    await Promise.all(promises)

    // Increment todays counter based on sentiment
    const dynamoDBCommand = new UpdateCommand({
        TableName: 'reddit-sentiment',
        Key: {
            date: todaysDate
        },
        UpdateExpression: 'SET #positive = if_not_exists(#positive, :start) + :positiveIncr, #negative = if_not_exists(#negative, :start) + :negativeIncr',
        ExpressionAttributeNames: {
            '#positive': 'positive',
            '#negative': 'negative'
        },
        ExpressionAttributeValues: {
            ':start': 0,
            ':positiveIncr': numPositive,
            ':negativeIncr': numNegative,
        },
        ReturnValues: 'UPDATED_NEW',
    });
    await documentClient.send(dynamoDBCommand);

    const response = {
        statusCode: 200,
        body: 'Success.'
    };
    return response;
};

// Returns today's date in MM/DD/YYYY format
const getTodaysDateFormatted = () => {
    const today = new Date();
    const yyyy = today.getFullYear();
    let mm = today.getMonth() + 1; // Months start at 0!
    let dd = today.getDate();

    if (dd < 10) dd = '0' + dd;
    if (mm < 10) mm = '0' + mm;

    const formattedToday = mm + '/' + dd + '/' + yyyy;
    return formattedToday;
}