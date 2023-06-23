import { ComprehendClient, DetectSentimentCommand } from "@aws-sdk/client-comprehend";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (event) => {
    const region = 'us-west-2';
    const comprehendClient = new ComprehendClient({ region: region });
    
    const comprehendParams = {
        LanguageCode: 'en',
        Text: event[0].payload.value.toString()
    };
    
    // Extract sentiment from Reddit comment
    const sentimentCommand = new DetectSentimentCommand(comprehendParams);
    const data = await comprehendClient.send(sentimentCommand);
    // Possible values: positive | negative | neutral | mixed
    const detectedSentiment = data.Sentiment.toLowerCase();

    // If sentiment is positive or neutral, set it to positive
    let sentiment = 'positive';

    // If sentiment is negative or mixed, set it to negative
    if (detectedSentiment === 'negative' || detectedSentiment === 'mixed') {
        sentiment = 'negative';
    }

    // Create DynamoDB client
    const dynamoDBClient = new DynamoDBClient({ region: region });
    const documentClient = DynamoDBDocumentClient.from(dynamoDBClient);

    const todaysDate = getTodaysDateFormatted();

    // Increment todays counter based on sentiment
    const dynamoDBCommand = new UpdateCommand({
        TableName: 'reddit-sentiment',
        Key: {
            date: todaysDate
        },
        UpdateExpression: 'SET #attrPath = if_not_exists(#attrPath, :start) + :inc',
        ExpressionAttributeNames: {
            '#attrPath': sentiment
        },
        ExpressionAttributeValues: {
            ':start': 0,
            ':inc': 1
        },
        ReturnValues: 'UPDATED_NEW',
    });
    await documentClient.send(dynamoDBCommand);

    const response = {
        statusCode: 200,
        body: JSON.stringify(`${sentiment} sentiment detected.`),
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