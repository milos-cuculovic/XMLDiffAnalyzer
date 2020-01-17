class XMLDiffAnalyzer:
    def __init__(self):
        self.tools = [
            ["", "xydiff", "xydiff ", " "],
            ["java -jar ", "jndiff", "jndiff/jndiff-ui.jar -d ", " "],
            ["java -jar ", "jxydiff", "jxydiff.jar ", " ", " "],
            ["ant -buildfile ", "fc-xmldiff", "fc-xmldiff/java/xmldiff/build.xml -Dbase=", " -Dnew=", " -Ddiff=", " diff"],
            ["java -jar ", "xcc", "xcc-java-0.90.jar --diff --doc ", " --changed ", " --delta "],
            ["", "node-delta", "node-delta/bin/djdiff.js -p xml ", " "],
            #["java -jar ", "deltaXML", "deltaXML/command-10.1.2.jar compare delta ", " ", " "], #License needed
            ["", "xmldiff", "xmldiff_bin -f xml ", " "], #Has issues with "UnicodeEncodeError: 'ascii' codec can't encode character u'\xe0' in position xxxx"
            ["java -jar ", "xop", "xop.jar -script on ", " - ", ""],
            ["java -cp ", "diffmk", "diffmk.jar net.sf.diffmk.DiffMk ", " ", " "],
            ["", "xdiff", "xdiff ", " ", " "],
            ["", "xdiff-go", "XDiff-go -left ", " -right ", ""],
            ["java -cp ", "diffxml", "diffxml.jar org.diffxml.diffxml.DiffXML ", " "]
        ]

    def start(self, mode, rounds, file_pairs, files_orig, files_new, file_delta_dir):
        import os
        import Processor
        import xlsxwriter
        from datetime import datetime

        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

        excel_headers = [
            [0, 'A1', 'Tool'],
            [1, 'B1', 'Rounds'],
            [2, 'C1', 'Average memory (MB)'],
            [3, 'D1', 'Max memory (MB)'],
            [4, 'E1', 'File orig size (KB)'],
            [5, 'F1', 'File modified size (KB)'],
            [6, 'G1', 'File delta size (KB)'],
            [7, 'H1', 'Time (sec)'],
            [8, 'I1', 'File orig'],
            [9, 'J1', 'File modified'],
            [10, 'K1', 'File delta'],
        ]

        workbook = xlsxwriter.Workbook(ROOT_DIR + "/ExcelResults/XMLDiffAnalyser_results_" + str(datetime.today().strftime('%Y%m%d_%H%M%S')) + ".xlsx",
                                       {'strings_to_numbers': True})
        worksheet = workbook.add_worksheet()

        header_format = workbook.add_format({
            'bold': True,
            'text_wrap': True,
            'fg_color': '#D7E4BC'})

        for excel_header in excel_headers:
            worksheet.write(excel_header[1], excel_header[2], header_format)
        worksheet.set_column('A:K', 20)

        if mode == "A":
            rounds_list = [1, 10, 100]
        else:
            rounds_list = [rounds]

        index = 0
        for file_pair in range(0, file_pairs):
            for rounds in rounds_list:
                print(str(rounds) + " round iteration")
                for tool in self.tools:
                    processor = Processor.Processor(ROOT_DIR, tool, rounds, file_pair, files_orig[file_pair], files_new[file_pair], file_delta_dir)
                    processor.start()
                    index += 1
                    worksheet.write(index, excel_headers[0][0], str(tool[1]))
                    worksheet.write(index, excel_headers[1][0], rounds)
                    worksheet.write(index, excel_headers[2][0], processor.average_memory)
                    worksheet.write(index, excel_headers[3][0], processor.max_memory)
                    worksheet.write(index, excel_headers[4][0], format((os.stat(files_orig[file_pair]).st_size) / (1024), '.2f'))
                    worksheet.write(index, excel_headers[5][0], format((os.stat(files_new[file_pair]).st_size) / (1024), '.2f'))
                    worksheet.write(index, excel_headers[6][0], processor.file_delta_size)
                    worksheet.write(index, excel_headers[7][0], processor.total_time)
                    worksheet.write(index, excel_headers[8][0], os.path.basename(files_orig[file_pair]))
                    worksheet.write(index, excel_headers[9][0], os.path.basename(files_new[file_pair]))
                    worksheet.write(index, excel_headers[10][0], os.path.basename(processor.file_delta))

                    print(tool[1] + " - file pair " + str(file_pair + 1))
                    # print("\t" + myCmd)    #For debug
                    print("\tTotal time:", str(processor.total_time) + " sec")
                    print("\tMax RSS Memory:", str(processor.max_memory) + " MB")
                    print("\tAverage memory:", str(processor.average_memory) + " MB")
                    print("\tFile delta:")
                    print("\t\tPath: " + processor.file_delta)
                    print("\t\tSize: ", str(processor.file_delta_size) + " KB")
                    print("")

        workbook.close()

if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()

    while True:
        mode = "X"
        input_files_orig = []
        input_files_new = []

        while not str(mode) in ("A", "M"):
            mode = input("Mode: M for Manual (default), A for Auto (1, 10, 100 rounds): ") or "M"

        input_rounds = 0
        if mode == "M":
            try:
                while not int(input_rounds) in range(1, 1000):
                    input_rounds = int(input("Enter the number of rounds between 1 and 1000 (default 1): ") or "1")
            except ValueError:
                print("Please provide a vaild number from 1 to 1000")

        file_pairs = 0
        try:
            while not int(file_pairs) in range(1, 40):
                file_pairs = int(input("Enter the number of file pairs between 1 and 40 (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number of file pairs from 1 to 40")

        for file_pair in range(1, file_pairs + 1):
            try:
                input_file_orig = input("Enter the full path of the original XML file pair " + str(file_pair) +": ") \
                                  or "/Users/miloscuculovic/XML_Diff_tools_material/Originals/article_min.xml"
            except ValueError:
                print("Please provide a vaild original XML file path")

            try:
                file_orig = open(input_file_orig)
            except IOError:
                print("Please provide a vaild original XML file path - File not accessible")
            finally:
                file_orig.close()

            try:
                input_file_new = input("Enter the full path of the modified XML file pair " + str(file_pair) + ": ") \
                                 or "/Users/miloscuculovic/XML_Diff_tools_material/TreeEdits/tree_edit_delete/article_min_tree_edit_delete.xml"
            except ValueError:
                print("Please provide a vaild modified XML file path")
            try:
                file_new = open(input_file_new)
            except IOError:
                print("Please provide a vaild modified XML file path - File not accessible")
            finally:
                file_new.close()

            if mode == "M" and (input_rounds < 1 or input_rounds > 1000):
                print("Please provide a vaild number from 1 to 1000")
                continue

            input_files_orig.append(input_file_orig)
            input_files_new.append(input_file_new)

        try:
            input_file_delta_dir = input("Enter the full path of the delta XML files directory: ") \
                                   or "/Users/miloscuculovic/XML_Diff_tools_material/"
        except ValueError:
            print("Please provide a vaild delta XML files directory file path")

        try:
            os.path.isdir(input_file_delta_dir)
        except IOError:
            print("Please provide a vaild modified XML file path - Directory not accessible")
        finally:
            file_new.close()

        xmlDiffAnalyzer.start(mode, input_rounds, file_pairs, input_files_orig, input_files_new, input_file_delta_dir)
