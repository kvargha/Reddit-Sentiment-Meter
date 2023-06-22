package sentiment.queue.processor;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import software.amazon.awssdk.regions.Region;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.SendMessageRequest;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.amazonaws.services.lambda.runtime.events.SQSEvent.SQSMessage;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.model.AttributeValue;

// ToDo set SQS concurrency limit to 1 to prevent race conditions

public class Handler implements RequestHandler<SQSEvent, Void> {
  Gson gson = new GsonBuilder().setPrettyPrinting().create();
  @Override
  public Void handleRequest(SQSEvent event, Context context) {
    String currentDate = getCurrentDate();

    // Get URL of queue
    AmazonSQS sqs = AmazonSQSClientBuilder.defaultClient();
    String QUEUE_NAME = "reddit_sentiment";
    String queueUrl = sqs.getQueueUrl(QUEUE_NAME).getQueueUrl();

    // Setup DynamoDB client
    Region region = Region.US_WEST_2;
    DynamoDbClient dynamoDbClient = DynamoDbClient.builder()
      .region(region)
      .build();
      
    // Define the table name and the key value to retrieve
    String tableName = "redditSentiment";
    String keyName = "date";
    String keyValue = currentDate;

    // Create a GetItemRequest to retrieve the item
    GetItemRequest request = GetItemRequest.builder()
      .tableName(tableName)
      .key(Collections.singletonMap(keyName, AttributeValue.builder().s(keyValue).build()))
      .build();
    
    // Retrieve the item from DynamoDB
    GetItemResponse response = dynamoDbClient.getItem(request);
    Map<String, AttributeValue> sentimentRecord = response.item();

    // If the record for the day doesn't exist, create a default structure
    if (sentimentRecord == null) {
      Map<String, AttributeValue> defaultSentimentRecord = new HashMap<>();
      defaultSentimentRecord.put("positive", 0);
      defaultSentimentRecord.put("negative", 0);

      sentimentRecord = defaultSentimentRecord;
    }

    // Iterate over messages from SQS
    for (SQSMessage msg : event.getRecords()) {
      String body = new String(msg.getBody());

      // Convert the stringified JSON to JSON object
      JSONObject jsonObject = new JSONObject(body);

      // Access the values from the JSON object
      String sentiment = jsonObject.getString("sentiment");

      // Increment counters
      if (sentiment == "positive" || sentiment == "neutral") {
        sentimentRecord["positive"] += 1;
      } else {
        sentimentRecord["negative"] += 1;
      }

      // Delete message from queue
      sqs.deleteMessage(queueUrl, msg.getReceiptHandle());
    }
    
    // Update DynamoDB record
    dynamoDbClient.putItem(tableName, sentimentRecord);
    return null;
  }
  
  // Returns current date in string format as MM/DD/YYYY
  public String getCurrentDate() {
    // Get the current date
    LocalDate currentDate = LocalDate.now();
    
    // Format the date as MM/DD/YYYY
    DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MM/dd/yyyy");
    String formattedDate = currentDate.format(formatter);
    return formattedDate;
  }
}