# Merges and converts the data from different data sources into one output JSON

from .awattar import parse_data as awattar_parse_data

def main():
    output = {"awattar": awattar_parse_data.main()}

    return output
