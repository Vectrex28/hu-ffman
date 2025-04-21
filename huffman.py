import os
import sys

from pathlib import Path

# Constants
_EMPTY_HUFFMAN_SLOT = 42069
_RESERVED_SLOT = 420


class HuffmanNode:
    """A representation of any node in a Huffman tree

    Attributes:
        - parent: The parent node
        - left_node: The left side node, self-explanatory
        - right_node: The right side node, also self-explanatory
        - value: The hex value represented by this node. 0xff means it's not a leaf!
        - size: How many instances of a byte does this node represent."""

    def __init__(self, in_value=0xff, in_size=0, in_left_node=None, in_right_node=None):
        self.parent = None
        self.left_node = None
        self.right_node = None
        self.value = in_value
        self.size = in_size

        # Only generate the left and right nodes if they exist, and calculate their sizes.
        if in_left_node is not None and in_right_node is not None:
            self.left_node = in_left_node
            self.right_node = in_right_node
            self.size = self.left_node.get_size() + self.right_node.get_size()

    def get_size(self):
        return self.size

    def get_value(self):
        return self.value

    def set_parent(self, in_parent_node):
        self.parent = in_parent_node

    # This guy generates the hex output reference recursively.
    def generate_hex_recursive(self, io_reference, io_leaves, io_output_string="", io_available_node=0):
        if self.value != 0xFF:
            io_reference[self.value] = io_output_string

        else:
            reserved_pos = io_available_node
            io_leaves[reserved_pos] = _RESERVED_SLOT
            io_leaves[reserved_pos + 1] = _RESERVED_SLOT

            while io_leaves[io_available_node] != _EMPTY_HUFFMAN_SLOT:
                io_available_node += 1

            io_leaves[reserved_pos] = io_available_node + 128
            self.left_node.generate_hex_recursive(io_reference, io_leaves, io_output_string + "0", io_available_node)
            if self.left_node.get_value() != 0xFF:
                io_leaves[reserved_pos] = self.left_node.get_value()

            while io_leaves[io_available_node] != _EMPTY_HUFFMAN_SLOT:
                io_available_node += 1

            io_leaves[reserved_pos + 1] = io_available_node + 128
            self.right_node.generate_hex_recursive(io_reference, io_leaves, io_output_string + "1", io_available_node)
            if self.right_node.get_value() != 0xFF:
                io_leaves[reserved_pos + 1] = self.right_node.get_value()

            return io_reference


def generate_huffman(in_directory):
    """This function takes a directory's contents and makes them huffman-compressed.
    The contents must be .bin files!"""

    # Parse the directory taken in as a parameter and spit out the .bin file contents
    directory_path = Path(in_directory)
    found_bin_files = list(directory_path.glob('*.bin'))

    # A dictionary where we shall gather our input data's byte frequency in.
    huffman_dic = {}
    all_file_contents = {}
    for bin_file in found_bin_files:
        with open(bin_file, "rb") as file_to_encode:
            file_contents = file_to_encode.read()
            all_file_contents[str(bin_file)] = file_contents
            for byte in file_contents:
                if byte in huffman_dic:
                    huffman_dic[byte] += 1
                else:
                    huffman_dic[byte] = 1

    # Once the dictionary has been generated, create a list of HuffmanNodes where the keys will be the hex values,
    # and the dictionary's values will become the size of each node.
    node_list = []
    for key, value in huffman_dic.items():
        node_from_dic = HuffmanNode(key, value)
        node_list.append(node_from_dic)

    # Generates the tree out of all the nodes we have in there, until there is only one node left in the list.
    # This last node will be our root, where we will start our parsing for huffman reference output.
    while len(node_list) > 1:
        # Sort all the current nodes from smallest to biggest.
        sorted_nodes = sorted(node_list, key=lambda node_to_sort: node_to_sort.get_size())

        # Prepare the upcoming left, right, and parent nodes. LR will become the parent's children, and will
        # get pruned from the list once their parent has been assigned.
        left_node = None
        right_node = None
        parent_node = None

        # Sift through the nodes until we can find the smallest nodes, and combine them into their parent.
        for sorted_node in sorted_nodes:
            if left_node is None:
                left_node = sorted_node
            else:
                right_node = sorted_node
                parent_node = HuffmanNode(0xff, 0, left_node, right_node)
                break

        # Once the nodes are combined, prune the child nodes from the list and continue the operation with the
        # parents and unprocessed nodes until only the root remains.
        sorted_nodes.remove(left_node)
        sorted_nodes.remove(right_node)
        sorted_nodes.append(parent_node)
        node_list = sorted_nodes

    # Now, we are going to generate the actual output list.
    # Arbitrary value 42069 is used as a "blank" value
    all_nodes_list = [_EMPTY_HUFFMAN_SLOT] * 128

    assert len(node_list) == 1, "The node list should only contain one item, that is the root node!"
    root_node = node_list[0]
    huffman_reference = {}
    huffman_reference = root_node.generate_hex_recursive(huffman_reference, all_nodes_list)

    # Generate the actual binary output here from the source file.
    encoded_strings = {}
    for original_filename, contents in all_file_contents.items():
        encoded_string = ""
        for byte in contents:
            encoded_string += huffman_reference[byte]

        # Pad the output to be a size divisible by 8 since we're dealing with bytes
        huffman_chunks = [encoded_string[i:i + 8] for i in range(0, len(encoded_string), 8)]
        huffman_chunks[-1] = huffman_chunks[-1].ljust(8, '0')
        print(f"{original_filename}:"
              f"\n  Original file size = {len(contents)} bytes"
              f"\n  Compressed file size = {len(huffman_chunks)} bytes")

        encoded_strings[original_filename] = huffman_chunks

    # Before we actually output the compressed chars, we shall first make our huffman tree lookup
    output_asm = "HuffmanLookup:"
    hexlength = 0
    for node_from_list in all_nodes_list:
        # Break if we arrived at the end, except if $FF is actually used
        if node_from_list == _EMPTY_HUFFMAN_SLOT:
            break

        if hexlength % 16 == 0:
            output_asm += "\n  .db $"
        else:
            output_asm += ",$"

        output_asm += format(node_from_list, '02X')
        hexlength += 1

    # The output ASM file is generated, now we check if the folder exists then write the ASM file.
    save_path = os.path.abspath(__file__).replace(os.path.basename(__file__), "")
    if not os.path.isdir(f"{save_path}\\output"):
        os.mkdir(f"{save_path}\\output")

    with open(f"{save_path}\\output\\huffman_lookup.asm", "w") as lookup_write:
        lookup_write.write(output_asm)

    # Finally, we take all the files, and output the compressed strings.
    for original_filename, huffman_chunks in encoded_strings.items():
        chunk_bytes = bytes(int(b, 2) for b in huffman_chunks)
        output_filename = original_filename.split('\\')[-1].replace(".bin", "_huffman.bin")
        with open(f"{save_path}\\output\\{output_filename}", "wb") as output_write:
            output_write.write(chunk_bytes)

    # Should be all done now :D
    exit(0)


if __name__ == '__main__':
    generate_huffman(str(Path(sys.argv[1])))
