import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async () => {
    const region = 'us-west-2';

    // Create DynamoDB client
    const dynamoDBClient = new DynamoDBClient({ region: region });
    const documentClient = DynamoDBDocumentClient.from(dynamoDBClient);

    const todaysDate = getTodaysDateFormatted();

    // Get sentiment count for the day
    const dynamoDBCommand = new GetCommand({
        TableName: 'reddit-sentiment',
        Key: {
            date: todaysDate
        }
    });
    
    const dynamoDBResponse = await documentClient.send(dynamoDBCommand);
    const data = dynamoDBResponse["Item"];

    let numComments = 0;
    let doomLevel = 0;

    // If the data for the day exists, extract the data
    if (data !== undefined) {
        const positiveCount = data["positive"] !== undefined ? data["positive"] : 0;
        const negativeCount = data["negative"] !== undefined ? data["negative"] : 0;

        numComments = positiveCount + negativeCount;

        doomLevel = roundToTwo((negativeCount / numComments) * 100);
    }

    return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            numComments: numComments,
            doomLevel: doomLevel
        })
    }
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

// Rounds to two decimal places
const roundToTwo = (num) => {
    return +(Math.round(num + 'e+2')  + 'e-2');
}