from dash import Dash, dcc, html
import plotly.graph_objs as go
from dash.dependencies import Input, Output
from firestore_query import get_data, fetch_data
# from flask_caching import Cache
import pandas as pd
from urllib.parse import urlparse, parse_qs
from flask import session
import os
import redis
import json

# Initialize the Dash app for hourly data
hourly_dash_app = Dash(__name__, routes_pathname_prefix="/hourly_dash/",
                       meta_tags=[{'name': 'viewport', 'content': 'width=device-width, initial-scale=1.0, maximum-scale=1.5, minimum-scale=0.5'}]
                       )

# user_id = None # Hardcoded for now, replace with dynamic inputs if needed
# watch_id = None # Hardcoded for now

# Initialize Redis Caching
redis_host = os.environ.get('REDISHOST','localhost')
redis_port = int(os.environ.get("REDISPORT", 6378))
cache = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

# def update_userinfo(user):
#     user_id = user
#     return

# Add layout for the hourly Dash app
hourly_dash_app.layout = html.Div(
    children=[
        dcc.Location(id='url-hourly', refresh=False),  # Capture URL parameters
        html.H1(
            children=" ",
        ),
        # Interval component for automatic updates
        dcc.Interval(
            id="interval-component-hourly",
            interval=60 * 1000,  # Refresh every 60 seconds
            n_intervals=0,
        ),
        # Add new hourly graphs
        html.Div(
            [
                dcc.Graph(id="hourly-hrv-graph", style={"margin-bottom": "1px"}),
                dcc.Graph(id="hourly-bpm-graph", style={"margin-bottom": "1px"}),
                dcc.Graph(id="hourly-steps-graph", style={"margin-bottom": "1px"}),
                dcc.Graph(id="hourly-spo2-graph", style={"margin-bottom": "1px"}),
            ], 
            style={
                "display": "flex",
                "flex-direction": "column",  # Makes sure graphs are stacked vertically
                "gap": "1px",  # Adds spacing between the graphs
                "margin-top": "3px",  # Adds space above the first graph
            }
        ),
    ]
)


# Callback function to update graphs based on the selected date from the URL
@hourly_dash_app.callback(
    [Output("hourly-hrv-graph", "figure"), 
     Output("hourly-bpm-graph", "figure"), 
     Output("hourly-steps-graph", "figure"),
     Output("hourly-spo2-graph", "figure")],
    [Input("interval-component-hourly", "n_intervals"), 
     Input('url-hourly', 'search')] # Captures the search part of the URL (query string)
)
def update_hourly_graphs(n_intervals, search):
    print("this function (hourly dash app) was triggered")
    # Get Session Params from Flask
    user_id = session.get('user_id')
    device_id = session.get('device_id')
    daydate = session.get('selected_date')

    # Fetch hourly data based on the user_id, watch_id, and selected date
    # _, hour_df, __ = get_data(user_id, device_id, daydate)
    _, hour_df, _ = fetch_data(user_id, device_id, daydate)

    if not hour_df.empty:
        # Ensure hour_df 'Date' and 'Time' columns are in datetime format
        hour_df["Date"] = pd.to_datetime(hour_df["Date"])
        hour_df["Time"] = pd.to_datetime(hour_df["Time"], format="%H:%M:%S")

    # Create figures with just axes, titles, and no data by default
    hourly_hrv_fig = go.Figure(layout=dict(
        title="Heart Rate Variability",
        xaxis=dict(tickformat="%I%p", dtick=3600000, showgrid=True, title="Time"),
        yaxis=dict(title="Milliseconds (ms)", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False
    ))
    
    hourly_bpm_fig = go.Figure(layout=dict(
        title="Heart Rate",
        xaxis=dict(tickformat="%I%p", dtick=3600000, showgrid=True, title="Time"),
        yaxis=dict(title="BPM", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False
    ))
    
    hourly_steps_fig = go.Figure(layout=dict(
        title="Steps",
        xaxis=dict(tickformat="%I%p", dtick=3600000, showgrid=True, title="Time"),
        yaxis=dict(title="Steps per hour", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False
    ))
    
    hourly_spo2_fig = go.Figure(layout=dict(
        title="SpO2",
        xaxis=dict(tickformat="%I%p", dtick=3600000, showgrid=True, title="Time"),
        yaxis=dict(title="SpO2 %", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False
    ))

    # Add traces only if data exists
    if not hour_df.empty and "hrv" in hour_df.columns:
        hourly_hrv_fig.add_trace(
            go.Scatter(
                x=hour_df["Time"],
                y=hour_df["hrv"],
                mode="lines+markers",
                hoverinfo="x+y",
                line=dict(width=4, shape="spline", smoothing=1.3, color="blue"),
                marker=dict(size=10, color="blue"),
            )
        )

    if not hour_df.empty and "bpm" in hour_df.columns:
        hourly_bpm_fig.add_trace(
            go.Scatter(
                x=hour_df["Time"],
                y=hour_df["bpm"],
                mode="lines+markers",
                hoverinfo="x+y",
                line=dict(width=4, shape="spline", smoothing=1.3, color="red"),
                marker=dict(size=10, color="red"),
            )
        )

    if not hour_df.empty and "steps" in hour_df.columns:
        hourly_steps_fig.add_trace(
            go.Scatter(
                x=hour_df["Time"],
                y=hour_df["steps"],
                mode="lines+markers",
                hoverinfo="x+y",
                line=dict(width=4, shape="spline", smoothing=1.3, color="green"),
                marker=dict(size=10, color="green"),
            )
        )
        
    if not hour_df.empty and "spo2" in hour_df.columns:
        hourly_spo2_fig.add_trace(
            go.Scatter(
                x=hour_df["Time"],
                y=hour_df["spo2"],
                mode="lines+markers",
                hoverinfo="x+y",
                line=dict(width=4, shape="spline", smoothing=1.3, color="orange"),
                marker=dict(size=10, color="orange"),
            )
        )

    return hourly_hrv_fig, hourly_bpm_fig, hourly_steps_fig, hourly_spo2_fig


# Function to add Dash to Flask
def add_hourly_dash(server):
    hourly_dash_app.init_app(server)
    hourly_dash_app.title = "Hourly Dashboard"
    return hourly_dash_app
