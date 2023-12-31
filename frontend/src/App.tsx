import React, { useState, useEffect } from "react";
import "./App.css";
import { 
  CssBaseline,
  Typography,
  Toolbar,
  Box,
  AppBar
} from "@mui/material";
import {
  styled,
  createTheme,
  ThemeProvider,
} from "@mui/material/styles";
import Odometer from "react-odometerjs"
import "odometer/themes/odometer-theme-default.css";
import GaugeComponent from "react-gauge-component";

const darkTheme = createTheme({
  palette: {
    mode: "dark",
  },
});

const Main = styled("main")<{}>(({ theme }) => ({
  flexGrow: 1,
  padding: theme.spacing(3),
  width: "100%",
  backgroundColor: theme.palette.background.default // Use the default background color from the theme
}));

function App() {
  const [numComments, setNumComments] = useState<number>(0);
  const [sentimentPercent, setSentimentPercent] = useState<number>(0);

  // Interval time in milliseconds (e.g., 5 seconds)
  // How often to call the Sentiment Level API
  const intervalTime = 5000;

  // Calls Lambda API to get the number of comments and sentiment levels
  const callSentimentLevelAPI = async () => {
    try {
      const response = await fetch("https://uqqojl9mv5.execute-api.us-west-2.amazonaws.com/prod/sentiment-level");
      const data = await response.json();
      
      // Process the retrieved data
      setNumComments(data["numComments"])
      setSentimentPercent(data["sentimentLevel"])
    } catch (error) {
      console.error("Error:", error);
    }
  };

  useEffect(() => {
    // Make initial call
    callSentimentLevelAPI();

    // Start the interval
    const intervalId = setInterval(callSentimentLevelAPI, intervalTime);

    // Clean up the interval on component unmount
    return () => {
      clearInterval(intervalId);
    };
  }, []);

  return (
    <ThemeProvider theme={darkTheme}>
      <Box sx={{ flexGrow: 1 }}>
        <CssBaseline />
        <AppBar position="fixed">
          <Toolbar>
            <Typography variant="h6" component="div">
              Reddit Sentiment Meter
            </Typography>
          </Toolbar>
        </AppBar>
        <Toolbar />
        <Main>

          <Odometer className="odometer" value={numComments} format="(,ddd)" style={{color: "white"}}/>
          <Typography variant="h5">Reddit Comments Analyzed Today</Typography>

          <GaugeComponent
            className="gauge"
            type="semicircle"
            arc={{
              gradient: true,
              width: 0.15,
              padding: 0,
              subArcs: [
                {
                  limit: 20,
                  color: "#5BE12C",
                  showMark: true
                },
                {
                  limit: 40,
                  color: "#F5CD19",
                  showMark: true
                },
                {
                  limit: 60,
                  color: "#F5CD19",
                  showMark: true
                },
                {
                  limit: 80,
                  color: "#DC143C",
                  showMark: true
                },
                { color: '#DC143C' }
              ]
            }}
            value={sentimentPercent}
            pointer={{type: "needle"}}
          />

          <Typography variant="h5">Sentiment Level</Typography>
        </Main>
      </Box>
    </ThemeProvider>
  );
}

export default App;
