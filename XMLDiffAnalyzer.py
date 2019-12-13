class XMLDiffAnalyzer:
    def __init__(self):
        self.tools = [
            ["", "xydiff", "xydiff ", " ", ""],
            ["java -jar ", "jndiff", "jndiff/jndiff-ui.jar -d ", " ", ""],
            ["java -cp ", "diffxml", "diffxml.jar org.diffxml.diffxml.DiffXML ", " ", ""],
            ["java -jar ", "xcc", "xcc-java-0.90.jar --diff --doc ", " --changed ", " --delta "],
            ["", "node-delta", "node-delta/bin/djdiff.js -p xml ", " ", ""],
            ["java -jar ", "deltaXML", "deltaXML/command-10.1.2.jar compare delta ", " ", " "],
            ["", "xmldiff", "xmldiff_bin -f xml ", " ", ""], #Has issues with "UnicodeEncodeError: 'ascii' codec can't encode character u'\xe0' in position xxxx"
            ["", "xdiff", "xdiff -left ", " -right ", ""],
            ["java -jar ", "xop", "xop.jar -script on ", " - ", ""],
            ["java -cp ", "diffmk", "diffmk.jar net.sf.diffmk.DiffMk ", " ", " "]
        ]

    def start(self, mode, rounds, file_orig, file_new, file_delta_dir):
        import os
        import Processor
        import xlsxwriter
        import time

        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

        excel_headers = [
            [0, 'A1', 'Tool'],
            [1, 'B1', 'Rounds'],
            [2, 'C1', 'Time (sec)'],
            [3, 'D1', 'Max memory (MB)'],
            [4, 'E1', 'Average memory (MB)'],
            [5, 'F1', 'File delta size KB)']
        ]

        workbook = xlsxwriter.Workbook(ROOT_DIR + "/ExcelResults/XMLDiffAnalyser_results_" + str(time.time()) + ".xlsx",
                                       {'strings_to_numbers': True})
        worksheet = workbook.add_worksheet()

        for excel_header in excel_headers:
            worksheet.write(excel_header[1], excel_header[2])
        worksheet.set_column('A:F', 20)

        if mode == "A":
            rounds_list = [1, 10, 100]
        else:
            rounds_list = [rounds]

        index = 0

        for rounds in rounds_list:
            print(str(rounds) + " round iteration")
            for tool in self.tools:
                processor = Processor.Processor(ROOT_DIR, tool, rounds, file_orig, file_new, file_delta_dir)
                processor.start()
                index += 1
                worksheet.write(index, excel_headers[0][0], str(tool[1]))
                worksheet.write(index, excel_headers[1][0], rounds)
                worksheet.write(index, excel_headers[2][0], processor.total_time)
                worksheet.write(index, excel_headers[3][0], processor.max_memory)
                worksheet.write(index, excel_headers[4][0], processor.average_memory)
                worksheet.write(index, excel_headers[5][0], processor.file_delta_size)

        workbook.close()

if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()
    print("Test for diff tools")
    while True:
        try:
            mode = input("Mode: M for Manual (default), A for Auto (1, 10, 100 rounds): " or "M")
        except ValueError:
            print("Please provide a vaild Mode")

        input_rounds = 0
        if mode == "M":
            try:
                while not int(input_rounds) in range(1, 1000):
                    input_rounds = int(input("Enter the number of rounds between 1 and 1000 (default 1): ") or "1")
            except ValueError:
                print("Please provide a vaild number from 1 to 1000")

        try:
            input_file_orig = input("Enter the full path of the original XML file: ") \
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
            input_file_new = input("Enter the full path of the modified XML file: ") \
                             or "/Users/miloscuculovic/XML_Diff_tools_material/TextEdits/text_edit_delete/article_min_text_edit_delete.xml"
        except ValueError:
            print("Please provide a vaild modified XML file path")

        try:
            file_new = open(input_file_new)
        except IOError:
            print("Please provide a vaild modified XML file path - File not accessible")
        finally:
            file_new.close()

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

        if mode == "M" and (input_rounds < 1 or input_rounds > 1000):
            print("Please provide a vaild number from 1 to 1000")
            continue
        xmlDiffAnalyzer.start(mode, input_rounds, input_file_orig, input_file_new, input_file_delta_dir)
