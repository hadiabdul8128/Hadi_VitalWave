from dash import Dash, dcc, html
import plotly.graph_objs as go
from plotly.subplots import make_subplots
from firestore_query import get_data, fetch_data
from dash.dependencies import Input, Output
import pandas as pd
from flask import session
from flask import request 
import os
import redis
import json
from datetime import date
from plotly.graph_objs import Figure


dash_app = Dash(__name__, routes_pathname_prefix="/dash/",
                meta_tags=[{'name': 'viewport', 'content': 'width=device-width, initial-scale=1.0, maximum-scale=1.5, minimum-scale=0.5'}]
                )

def is_ios():
    """Detect if the request is from an iOS device."""
    agent = request.headers.get('User-Agent').lower()
    return 'iphone' in agent or 'ipad' in agent or 'ipod' in agent

redis_host = os.environ.get('REDISHOST')
redis_port = int(os.environ.get("REDISPORT", 6378))
cache = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)


def fetch_data(user_id, watch_id, daydate): ## Not working because redis not working!!
    query_output = get_data(user_id, watch_id, daydate)
    query_out_cache = get_data(user_id, watch_id, daydate)
    # Serialize each dataframe in the tuple
    serialized_tuple = {
        "day": query_out_cache[0].to_json(orient='split'),
        "hour": query_out_cache[1].to_json(orient='split'),
        "minute": query_out_cache[2].to_json(orient='split')
    }

    print(f"FETCH DATA------------------------------\n\n{query_output}\n\n")
    cache.set(user_id,json.dumps({watch_id: serialized_tuple}))
    cache.expire(user_id, 60)
    cached_data_json = cache.get(user_id)
    if cached_data_json is not None:
        cached_data = json.loads(cached_data_json)
        watch_data = cached_data.get(watch_id)
        if watch_data is not None:
            query_data = pd.read_json(watch_data["day"], orient='split')
            print(f"GET DATA------------------------------\n\n{query_data}\n\n")
        else:
            print(f"No data found for watch id {watch_id}")
    else:
        print(f"No data found for user id {user_id}")
    return query_output


# 
dash_app.layout = html.Div(
    id="main-content",
    children=[
        html.H1(children=" "),
        
        html.Div(
            id = "dropdown-container",
            children=[
                dcc.Dropdown(
                    id='device-dropdown',
                    options=[],  # Options will be dynamically populated
                    placeholder="Select a Device",
                    # style={
                    #     'width': '150px',
                    #     'margin-right': '10px',
                    #     'height': '47px',  
                    #     # 'margin-top': '10px',
                    #     # 'textAlign': 'center',
                    # }
                    
                    
                ),
                dcc.DatePickerSingle(
                    id='date-picker',
                    min_date_allowed=pd.to_datetime('2022-01-01'),
                    max_date_allowed=pd.to_datetime('2024-12-31'),
                    initial_visible_month=pd.to_datetime(date.today()),
                    date=pd.to_datetime(date.today()),  # Default date
                    # style = {
                    #     'width': '175px',
                    #     'height': '50px',
                    #     'margin-right': '-20px',
                    #     'textAlign': 'center',
                    # }
                ),
            ],
            # style={
            #     'display': 'flex',  # Arrange children in a row
            #     # 'align-items': 'center',  # Vertically align items
            #     # 'justify-content': 'center',  # Center horizontally --
            #     'position': 'fixed',
            #     'top': '10px',
            #     'left': '50%',
            #     'transform': 'translateX(-50%)',
            #     'zIndex': 1000,
            #     'backgroundColor': 'white',
            #     'padding': '10px',
            #     'boxShadow': '0px 4px 6px rgba(0, 0, 0, 0.1)',
            #     'borderRadius': '8px',
            # }
        ),
        
        
        
        # Interval component for automatic updates
        dcc.Interval(
            id="interval-component",
            interval=60 * 1000,  # Refresh every 60 seconds (60000 milliseconds)
            n_intervals=0,
        ),
        dcc.Interval(
            id="interval-component-hourly",
            interval=60 * 1000,  # Refresh every 60 seconds
            n_intervals=0,
        ),
        # Graph with subplots for HRV, BPM, and Biomarker 1 Data from day_df
        dcc.Graph(id="subplot-graph", className = "dash-graph"),
        html.Div(
            [
                dcc.Graph(id="hourly-hrv-graph", className = "dash-graph", style = {'width': '100%'}),
                dcc.Graph(id="hourly-bpm-graph", className = "dash-graph", style = {'width': '100%'}),
                dcc.Graph(id="hourly-steps-graph", className = "dash-graph", style = {'width': '100%'}),
                dcc.Graph(id="hourly-spo2-graph", className = "dash-graph", style = {'width': '100%'}),
            ], 
            style={
                "display": "flex",
                "flex-direction": "column",  # Makes sure graphs are stacked vertically
                "gap": "1px",  # Adds spacing between the graphs
                "margin-top": "3px",  # Adds space above the first graph
                "width": "100%"
            }
        ),
        
        html.Div(
            id='statistics-box',
            style={
                "display": "flex",
                "justify-content": "center",
                "align-items": "center",
                "gap": "20px",  # Adjusted spacing between boxes
                "margin-top": "40px",
                "margin-bottom": "20px",
            },
            children=[
                html.Div(
                    id='statistic-1',
                    style={
                        "padding": "15px",
                        "width": "150px",
                        "height": "80px",
                        "backgroundColor": "white",
                        "boxShadow": "0px 4px 10px rgba(0, 0, 0, 0.1)",
                        "borderRadius": "10px",
                        "textAlign": "center",
                        "fontSize": "18px",
                        "fontWeight": "bold",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "center",
                        "alignItems": "center",
                    },
                    children="Statistic 1"
                ),
                html.Div(
                    id='statistic-2',
                    style={
                        "padding": "15px",
                        "width": "150px",
                        "height": "80px",
                        "backgroundColor": "white",
                        "boxShadow": "0px 4px 10px rgba(0, 0, 0, 0.1)",
                        "borderRadius": "10px",
                        "textAlign": "center",
                        "fontSize": "18px",
                        "fontWeight": "bold",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "center",
                        "alignItems": "center",
                    },
                    children="Statistic 2"
                ),
                html.Div(
                    id='statistic-3',
                    style={
                        "padding": "15px",
                        "width": "150px",
                        "height": "80px",
                        "backgroundColor": "white",
                        "boxShadow": "0px 4px 10px rgba(0, 0, 0, 0.1)",
                        "borderRadius": "10px",
                        "textAlign": "center",
                        "fontSize": "18px",
                        "fontWeight": "bold",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "center",
                        "alignItems": "center",
                    },
                    children="Statistic 3"
                )
            ]
        ),

        
        
    ]
)

@dash_app.callback(
    Output("main-content", "style"),
    Input("interval-component", "n_intervals") 
)

def apply_margins(n_intervals): 
    content_style = {
        "maxWidth": "100%", 
        "margin": "0 auto", 
    }
    # ios = is_ios() 
    # if ios: 
    #     content_style["margin-left"] = "60px"
    return content_style

@dash_app.callback(
    [Output("dropdown-container", "style"),
    Output("device-dropdown", "style"),
    Output("date-picker", "style")],
    Input("interval-component", "n_intervals") 
)
def apply_dropdown_margins(n_intervals): 
    container_style = {
        'display': 'flex',  # Arrange children in a row
        # 'align-items': 'center',  # Vertically align items
        # 'justify-content': 'center',  # Center horizontally --
        'position': 'fixed',
        'top': '10px',
        'left': '50%',
        'transform': 'translateX(-50%)',
        'zIndex': 1000,
        'backgroundColor': 'white',
        'padding': '10px',
        'boxShadow': '0px 4px 6px rgba(0, 0, 0, 0.1)',
        'borderRadius': '8px',
    }
    dropdown_style = {
        'width': '150px',
        'margin-right': '10px',
        'height': '47px',
    }
    datepicker_style = {
        'width': '175px',
        'height': '50px',
        'margin-right': '-20px',
        'textAlign': 'center',
    }
    # ios = is_ios() 
    # if ios: 
    #     container_style["width"] = '280px'
    #     # container_style["justify-content"] = 'center'
    #     # container_style['align-items'] = 'center'  # Vertically align items
    #     dropdown_style["width"] = '130px'
    #     datepicker_style["width"] = '150px'
        
    #     container_style["margin-left"] = '30px'
        
        
    return container_style, dropdown_style, datepicker_style 

@dash_app.callback(
    Output('device-dropdown', 'options'),
    Input('interval-component', 'n_intervals'),  # Periodic updates
)
def update_dropdown_options(n_intervals):
    device_map = session.get('device_ids', {})
    if not device_map:
        return []  # Return an empty list if device_map is not available
    
    # Create dropdown options from device_map
    options = [{"label": name, "value": device_id} for device_id, name in device_map.items()]
    return options



# Callback to update graph at specified intervals
@dash_app.callback(
    [
        Output("subplot-graph", "figure"),
        Output("hourly-hrv-graph", "figure"),
        Output("hourly-bpm-graph", "figure"),
        Output("hourly-steps-graph", "figure"),
        Output("hourly-spo2-graph", "figure"),
        Output("statistics-box", "children"),
    ],
    [
        Input("device-dropdown", "value"),  # Dropdown for selected device
        Input("date-picker", "date"),
        Input("interval-component", "n_intervals"),
    ]
)

def update_graphs(selected_device, selected_date, n_intervals):
    ios = is_ios() 
    
    print(f"Is iOS device: {ios}")
    
    def empty_figure(title):
        fig = Figure()
        fig.update_layout(
            title=title,
            xaxis={"visible": True, "showticklabels": True, "title": "Time"},
            yaxis={"visible": True, "showticklabels": True, "title": "Value"},
            plot_bgcolor="white",
            paper_bgcolor="white",
            showlegend=False
        )
        return fig

    # Default figures before selection
    default_subplot_fig = empty_figure("HRV, BPM, and Steps")
    default_hourly_hrv_fig = empty_figure("Heart Rate Variability")
    default_hourly_bpm_fig = empty_figure("Heart Rate")
    default_hourly_steps_fig = empty_figure("Steps")
    default_hourly_spo2_fig = empty_figure("SpO2")

    if not selected_device or not selected_date:
        # Default statistics display
        statistics_display = [
            html.Div("Total Steps: 0", style={"color": "#007bff"}),
            html.Div("Avg HRV: 0 ms", style={"color": "#28a745"}),
            html.Div("Avg BPM: 0 bpm", style={"color": "#dc3545"}),
        ]
        return (
            default_subplot_fig,
            default_hourly_hrv_fig,
            default_hourly_bpm_fig,
            default_hourly_steps_fig,
            default_hourly_spo2_fig,
            statistics_display,
        )
    
    user_id = session.get('user_id') 

    # device_id = 'E4C41215-B262-3FA3-9658-0BC2276E59E2' ## CHANGE THIS
    daydate = selected_date
    
    if not selected_date:
        selected_date = pd.to_datetime('today').strftime('%m-%d-%Y')  # Default to today's date
    else:
        selected_date = pd.to_datetime(selected_date).strftime('%m-%d-%Y')

    # Fetch data from Firestore
    try:
        day_df, hour_df, _ = get_data(user_id, selected_device, selected_date)
    except Exception as e:
        print(f"Error fetching data: {e}")
        return {}, {}, {}, {}, {}
    # Convert 'Date' column to datetime if it's not already
    if not day_df.empty:
        daydate = pd.to_datetime(daydate)
        day_df["Date"] = pd.to_datetime(day_df["Date"])
        
    if not hour_df.empty:
        # Ensure hour_df 'Date' and 'Time' columns are in datetime format
        hour_df["Date"] = pd.to_datetime(hour_df["Date"])
        hour_df["Time"] = pd.to_datetime(hour_df["Time"], format="%H:%M:%S")
        
    if not day_df.empty:
        total_steps = int(day_df["steps"].sum()) if "steps" in day_df.columns else 0
        avg_hrv = round(day_df["hrv"].mean(), 2) if "hrv" in day_df.columns else 0
        avg_bpm = round(day_df["bpm"].mean(), 2) if "bpm" in day_df.columns else 0
    else:
        total_steps, avg_hrv, avg_bpm = 0, 0, 0

    # Create statistics display
    statistics_display = [
        html.Div(f"Total Steps: {total_steps}", style={"color": "#007bff"}),
        html.Div(f"Avg HRV: {avg_hrv} ms", style={"color": "#28a745"}),
        html.Div(f"Avg BPM: {avg_bpm} bpm", style={"color": "#dc3545"}),
    ]

    

    

    # Create subplots with shared x-axis and increased vertical spacing between subplots
    fig = make_subplots(
        rows=3, cols=1, shared_xaxes=True, vertical_spacing=0.15
    )  # No subplot_titles added here

    # Plot Day Data: HRV
    if not day_df.empty:
        fig.add_trace(
            go.Scatter(
                x=day_df["Date"],
                y=day_df["hrv"],
                mode="lines+markers",
                hoverinfo="x+y",
                name="Day HRV",
                line=dict(width=4, shape="spline"),
                marker=dict(size=10),
            ),  # Set marker size here
            row=1,
            col=1,
        )

    # Plot Day Data: BPM
    if not day_df.empty:
        fig.add_trace(
            go.Scatter(
                x=day_df["Date"],
                y=day_df["bpm"],
                mode="lines+markers",
                hoverinfo="x+y",
                name="Day BPM",
                line=dict(width=4, shape="spline"),
                marker=dict(size=10),
            ),  # Set marker size here
            row=2,
            col=1,
        )

    # Plot Day Data: Biomarker 1
    if not day_df.empty:
        fig.add_trace(
            go.Scatter(
                x=day_df["Date"],
                y=day_df["steps"],
                mode="lines+markers",
                hoverinfo="x+y",
                name="Day Steps",
                line=dict(width=4, shape="spline"),
                marker=dict(size=10),
            ),  # Set marker size here
            row=3,
            col=1,
        )
        
    x_axis_ticks = {
        "tickformat": "%I%p", 
        "dtick": 3600000,
        "showgrid": True, 
        "tickfont": dict(size = 10), 
        "title": None, 
        "automargin": True
    }
    
    margins = {
        "l": 80,
        "r": 80,
        "t": 100, 
        "b": 80
    }
        
    if ios: 
        x_axis_ticks["dtick"] = 21600000
    if ios: 
        margins["l"] = 5
        margins["r"] = 5
        
    hourly_hrv_fig = go.Figure(layout=dict(
        title="Heart Rate Variability",
        xaxis=x_axis_ticks,
        yaxis=dict(title="Milliseconds (ms)", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False, 
        margin = margins 
    ))
    
    hourly_bpm_fig = go.Figure(layout=dict(
        title="Heart Rate",
        xaxis=x_axis_ticks,
        yaxis=dict(title="BPM", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False,
        margin = margins
    ))
    
    hourly_steps_fig = go.Figure(layout=dict(
        title="Steps",
        xaxis=x_axis_ticks,
        yaxis=dict(title="Steps per hour", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False,
        margin = margins
    ))
    
    hourly_spo2_fig = go.Figure(layout=dict(
        title="SpO2",
        xaxis=x_axis_ticks, 
        yaxis=dict(title="SpO2 %", showgrid=True, gridcolor="lightgray"),
        plot_bgcolor="white", paper_bgcolor="white", showlegend=False,
        margin = margins
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

    # Calculate the middle of the x-axis (median date) to place the dashed line
    x_mid = daydate
    
    margins = {
        "l": 80,
        "r": 80,
        "t": 80, 
        "b": 20
    }
    
    if ios: 
        margins["t"] = 100
        margins["l"] = 5
        margins["r"] = 5

    # Add vertical dashed line across all subplots
    fig.update_layout(
        height=600,  # Adjusted height for more space
        margin=margins,  # Increased top margin to prevent title from going off the edge
        showlegend=False,  # Hides the legend from the plot
        shapes=[
            dict(
                type="line",
                xref="x",
                yref="paper",  # Relative to the full figure height
                x0=x_mid,
                x1=x_mid,
                y0=0,
                y1=1,
                line=dict(
                    color="black",
                    width=3,
                    dash="dash",
                ),
            ),
            # Add horizontal lines below each title
            dict(
                type="line",
                xref="paper",
                yref="paper",
                x0=0,
                x1=1,
                y0=1,
                y1=1,  # Position the line just below the title for the first subplot
                line=dict(color="gray", width=2),
            ),
            dict(
                type="line",
                xref="paper",
                yref="paper",
                x0=0,
                x1=1,
                y0=0.63,
                y1=0.63,  # Position the line just below the title for the second subplot
                line=dict(color="gray", width=2),
            ),
            dict(
                type="line",
                xref="paper",
                yref="paper",
                x0=0,
                x1=1,
                y0=0.25,
                y1=0.25,  # Position the line just below the title for the third subplot
                line=dict(color="gray", width=2),
            ),
        ],
        plot_bgcolor="rgba(0,0,0,0)",  # Transparent plot background
        paper_bgcolor="rgba(0,0,0,0)",
        annotations=[  # Manually add titles and increase font size
            dict(
                text="HRV",
                x=0,  # Left align
                y=1.05,  # Adjusted y position to prevent title from going off the top
                xref="paper",
                yref="paper",
                showarrow=False,
                font=dict(size=18, color="black", family="Helvetica"),  # Increased font size here
            ),
            dict(
                text="BPM",
                x=0,  # Left align
                y=0.65,
                xref="paper",
                yref="paper",
                showarrow=False,
                font=dict(size=18, color="black", family="Helvetica"),  # Increased font size here
            ),
            dict(
                text="Steps",
                x=0,  # Left align
                y=0.25,
                xref="paper",
                yref="paper",
                showarrow=False,
                font=dict(size=18, color="black", family="Helvetica"),  # Increased font size here
            ),
        ],
    )

    # Add individual y-axis titles and adjust padding between graphs
    # fig.update_yaxes(title_text="HRV", row=1, col=1, automargin=True)
    # fig.update_yaxes(title_text="BPM", row=2, col=1, automargin=True)
    # fig.update_yaxes(title_text="Steps", row=3, col=1, automargin=True)

    # Remove horizontal hover lines and only allow vertical spikes
    fig.update_xaxes(showspikes=False, showgrid=False)
    fig.update_yaxes(showspikes=False, showgrid=False)

    # Return the figure
    return fig, hourly_hrv_fig, hourly_bpm_fig, hourly_steps_fig, hourly_spo2_fig, statistics_display


# Function to add Dash to Flask
def add_dash(server):
    dash_app.init_app(server)  # Attach Dash app to Flask
    dash_app.title = "Dashboard"
    return dash_app
