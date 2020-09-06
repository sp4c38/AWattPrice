# Merges and converts the data from different data sources into one output JSON

def main(awattar):
    output = {"awattar": {"prices": ""}}
    
    output["awattar"]["prices"] = awattar["data"]

    return output
