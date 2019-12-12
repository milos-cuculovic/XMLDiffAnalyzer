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

    def start(self, rounds, file_orig, file_new, file_delta_dir):
        import os
        import ProcessTimer
        import time
        import xlsxwriter

        ROOT_DIR = os.path.abspath(os.curdir)

        print("Starting...")

        excel_headers = [
            [0, 'A1', 'Tool'],
            [1, 'B1', 'Time (sec)'],
            [2, 'C1', 'Max memory (MB)'],
            [3, 'D1', 'Average memory (MB)'],
            [4, 'E1', 'File delta size KB)']
        ]

        workbook = xlsxwriter.Workbook(ROOT_DIR + "/ExcelResults/XMLDiffAnalyser_results_" + str(time.time()) + ".xlsx",
                                       {'strings_to_numbers':  True})
        worksheet = workbook.add_worksheet()

        for excel_header in excel_headers:
            worksheet.write(excel_header[1], excel_header[2])
        worksheet.set_column('A:E', 20)

        for index, row in enumerate(self.tools):
            total_time = 0
            max_memory = 0
            average_memory = []

            myCmd = row[0] + ROOT_DIR + "/XMLDiffTools/" + row[2] + file_orig + row[3] + file_new
            file_delta = file_delta_dir + row[1] + "_delta.xml"

            first_round = True
            for round in range(0, rounds):

                if row[4] != "":
                    myCmd += row[4] + file_delta
                elif first_round:
                    myCmd += " >> " + file_delta
                    first_round = False

                ptimer = ProcessTimer.ProcessTimer(myCmd)

                try:
                    ptimer.execute()
                    # poll as often as possible; otherwise the subprocess might
                    # "sneak" in some extra memory usage while you aren't looking
                    while ptimer.poll():
                        time.sleep(.0001)
                finally:
                    # make sure that we don't leave the process dangling?
                    ptimer.close()

                current_time = ptimer.t1 - ptimer.t0
                total_time += current_time
                max_memory = max(max_memory, ptimer.max_rss_memory)
                average_memory.append(sum(ptimer.rss_memory) / len(ptimer.rss_memory))

            total_time = format(total_time,'.2f')
            max_memory = format((max_memory) / (1024 * 1024), '.3f')
            average_memory = format((sum(average_memory) / len(average_memory)) / (1024 * 1024), '.3f')
            file_delta_size = format((os.stat(file_delta).st_size) / (1024 ), '.2f')

            index += 1
            worksheet.write(index, excel_headers[0][0], str(row[1]))
            worksheet.write(index, excel_headers[1][0], total_time)
            worksheet.write(index, excel_headers[2][0], max_memory)
            worksheet.write(index, excel_headers[3][0], average_memory)
            worksheet.write(index, excel_headers[4][0], file_delta_size)

            print(row[1] + ":")
            #print("\t" + myCmd)    #For debug
            print("\tTotal time:", total_time + " sec")
            print("\tMax RSS Memory:", str(max_memory) + " MB")
            print("\tAverage memory:", str(average_memory) + " MB")
            print("\tFile delta:")
            print("\t\tPath: " + file_delta)
            print("\t\tSize: ", str(file_delta_size) + " KB")

        workbook.close()

if __name__ == '__main__':
    import os
    xmlDiffAnalyzer = XMLDiffAnalyzer()
    print("Test for diff tools")
    while True:
        try:
            input_rounds = int(input("Enter the number of rounds (default 1): ") or "1")
        except ValueError:
            print("Please provide a vaild number from 1 to 10 000")

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

        if input_rounds < 1 or input_rounds > 10000:
            print("Please provide a vaild number from 1 to 10 000")
            continue
        xmlDiffAnalyzer.start(input_rounds, input_file_orig, input_file_new, input_file_delta_dir)
