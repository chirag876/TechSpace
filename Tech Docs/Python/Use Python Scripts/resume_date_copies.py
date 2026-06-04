import os
import shutil
import calendar


def generate_resume_copies():
    pdf_path = input("Enter PDF file path: ").strip()

    if not os.path.isfile(pdf_path):
        print("PDF file not found!")
        return

    month = int(input("Enter month (1-12): "))
    year = int(input("Enter year (e.g. 2026): "))

    days_in_month = calendar.monthrange(year, month)[1]

    output_folder = "Resume"
    os.makedirs(output_folder, exist_ok=True)

    pdf_name = os.path.splitext(os.path.basename(pdf_path))[0]

    for day in range(1, days_in_month + 1):
        date_suffix = f"{day:02d}-{month:02d}-{year}"

        new_file_name = f"{pdf_name}_{date_suffix}.pdf"
        destination = os.path.join(output_folder, new_file_name)

        shutil.copy2(pdf_path, destination)

    print(
        f"\nSuccessfully created {days_in_month} PDFs in '{output_folder}' folder."
    )


if __name__ == "__main__":
    generate_resume_copies()