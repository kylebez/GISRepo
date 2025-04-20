import test_rust_utm_converter as pyo3_example # pylint: disable=missing-docstring
from utm_c import utm_
import argparse
import timeit

def wrapper_rust_function(lat, lon):
    global Rresult
    Rresult = pyo3_example.to_utm_no_zone(lat, lon)  # pylint: disable=no-member

def wrapper_python_function(lat, lon):
    global Presult
    pyConverter = utm_("wgs84")
    Presult = utm_.ll2utm(pyConverter, lat, lon)  # pylint: disable=no-member

def perfCompare(lat, lon):
    # Measure execution time using timeit
    execution_time = timeit.timeit(lambda: wrapper_rust_function(lat, lon), number=1)
    print(f"Rust result: {Rresult} \n Execution time: {execution_time:.6f}")
    execution_time = timeit.timeit(lambda: wrapper_python_function(lat, lon), number=1)
    print(f"Python result: {Presult} \n Execution time: {execution_time:.6f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert latitude and longitude to UTM.")
    parser.add_argument("latitude", type=float, help="Latitude in decimal degrees")
    parser.add_argument("longitude", type=float, help="Longitude in decimal degrees")
    args = parser.parse_args()

    perfCompare(args.latitude, args.longitude)