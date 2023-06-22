package example;

import com.amazonaws.services.lambda.runtime.Context;


// Handler value: example.Handler
public class Handler {
  public String handleRequest(String input, Context context)
  {
    context.getLogger().log("hi");
    return "Hi";
  }
}