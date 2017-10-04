# %matplotlib inline
import geopandas as gpd
import pandas as pd
from shapely.geometry import Point, MultiPoint
from shapely.wkb import loads
from configparser import ConfigParser


config = ConfigParser()
config.read("quadgrid.conf")

THRESHOLD = int(config["data"]["threshold"])
RESOLUTION = int(config["data"]["resolution"])
DATASET = config["data"]["dataset"]


def split_cell(cell, points_in_cell):
    # This grid will contain the result of splitting the cell into subcells:
    #   - If none of the subcells turn out to have more than THRESHOLD points, the grid will contain the cell itself
    #   - If one or more subcells have more than THRESHOLD points, then the grid will contain those cells
    grid = gpd.GeoDataFrame(crs={"init": "epsg:3857"}, geometry=[], columns=["num_points"])

    # Return empty grid if there aren't enough points in the cell
    if len(points_in_cell) < THRESHOLD:
        return(grid)

    # Return empty grid if cell is already too small
    bounds = cell.bounds
    if (bounds[2] - bounds[0]) < (2 * RESOLUTION):
        return(grid)

    # Cell can be split

    # We'll use the center and the corners of the cell to actually split it
    center = cell.centroid
    vertices_coords = cell.exterior.coords.xy
    vertices = [Point(longitude, vertices_coords[1][i]) for i, longitude in enumerate(vertices_coords[0][:-1])]

    # Get the subcells
    all_four_under_threshold = True
    for vertex in vertices:
        new_cell = MultiPoint([vertex, center]).envelope
        points_in_new_cell = points_in_cell.loc[lambda point: point.intersects(new_cell), :]
        num_points_in_new_cell = len(points_in_new_cell)
        if num_points_in_new_cell > THRESHOLD:
            all_four_under_threshold = False
            grid = grid.append(split_cell(new_cell, points_in_new_cell))

    if all_four_under_threshold is True:
        grid = grid.append(pd.Series([cell, len(points_in_cell)], ["geometry", "num_points"]), ignore_index=True)

    return(grid)


# Load dataset and reproject
points = gpd.GeoDataFrame(pd.read_csv(DATASET))
points.geometry = points.apply(lambda point: loads(point.the_geom, hex=True), axis=1)
points.crs = {"init": "epsg:4326"}
points = points.to_crs({"init": "epsg:3857"})

# Let's start with the envelope of all the points and split from there
initial_cell = points.unary_union.envelope
grid = split_cell(initial_cell, points)

grid.plot()
