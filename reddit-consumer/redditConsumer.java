package reddit.consumer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider;
import software.amazon.awssdk.services.comprehend.ComprehendClient;
import software.amazon.awssdk.services.comprehend.model.ComprehendException;
import software.amazon.awssdk.services.comprehend.model.DetectSentimentRequest;
import software.amazon.awssdk.services.comprehend.model.DetectSentimentResponse;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.SendMessageRequest;


public class Handler implements RequestHandler<Map<String,String>, String> {
  Gson gson = new GsonBuilder().setPrettyPrinting().create();
  @Override
  public String handleRequest(Map<String, String> event, Context context) {
    Region region = Region.US_WEST_2;

    // Create AWS Comprehend client
    ComprehendClient comprehendClient = ComprehendClient.builder()
      .region(region)
      .credentialsProvider(ProfileCredentialsProvider.create())
      .build();

    // Extract reddit comment
    String text = event["text"];

    // Detect sentiment
    DetectSentimentRequest detectSentimentRequest = DetectSentimentRequest.builder()
      .text(text)
      .languageCode("en")
      .build();

    // Possible outputs: POSITIVE | NEGATIVE | NEUTRAL | MIXED
    DetectSentimentResponse detectSentimentResult = comprehendClient.detectSentiment(detectSentimentRequest);
    String sentiment = detectSentimentResult.getSentiment().toLowerCase();

    // Create JSON string to be sent to SQS
    JSONObject json = new JSONObject();
    json.put("sentiment", sentiment);
    String jsonString = json.toString();

    // Send message to SQS
    AmazonSQS sqs = AmazonSQSClientBuilder.defaultClient();
    String QUEUE_NAME = "reddit_sentiment";
    String queueUrl = sqs.getQueueUrl(QUEUE_NAME).getQueueUrl();

    SendMessageRequest sendMsgRequest = new SendMessageRequest()
      .withQueueUrl(queueUrl)
      .withMessageBody(jsonString);
    sqs.sendMessage(sendMsgRequest);

    String response = new String("200 OK");
    return response;
  }
}