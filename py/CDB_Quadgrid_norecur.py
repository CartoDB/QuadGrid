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


# Load dataset and reproject
initial_points = gpd.GeoDataFrame(pd.read_csv(DATASET))
initial_points.geometry = initial_points.apply(lambda point: loads(point.the_geom, hex=True), axis=1)
initial_points.crs = {"init": "epsg:4326"}
initial_points = initial_points.to_crs({"init": "epsg:3857"})

# Let's start with the envelope of all the points and split from there
initial_cell = initial_points.unary_union.envelope
# Let's make it a square
initial_cell_centroid = initial_cell.centroid
initial_cell_vertices_coords = initial_cell.exterior.coords.xy
one_vertex = Point((initial_cell_vertices_coords[0][0], initial_cell_vertices_coords[1][0]))
initial_cell = initial_cell_centroid.buffer(initial_cell_centroid.distance(one_vertex)).envelope

# We start with the initial cell
remaining_cells = [(initial_cell, initial_points)]

# This grid will be hosting the leaf cells
grid = gpd.GeoDataFrame(crs={"init": "epsg:3857"}, geometry=[], columns=["num_points"])


def split_cell(cell, points_in_cell):
    # Discard this cell if there aren't enough points in it
    if len(points_in_cell) < THRESHOLD:
        return(None, None)

    # Discard this cell if it's already too small
    bounds = cell.bounds
    if (bounds[2] - bounds[0]) < (2 * RESOLUTION):
        return(None, None)

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
            # If the subcell has more than THRESHOLD points, it needs to be split again
            remaining_cells.append((new_cell, points_in_new_cell))

    # If none of the subcells turn out to have more than THRESHOLD points, the grid will contain the cell itself
    if all_four_under_threshold is True:
        return(cell, points_in_cell)

    # Covers the case where the last processed cell has less points than threshold but at least one of the previous ones did qualify
    return(None, None)


while len(remaining_cells) > 0:
    (cell, points_in_cell) = remaining_cells.pop()
    (new_cell, points_in_new_cell) = split_cell(cell, points_in_cell)
    if new_cell is not None:
        grid = grid.append(pd.Series([new_cell, len(points_in_new_cell)], ["geometry", "num_points"]), ignore_index=True)


grid.plot()
