import fitz
from googletrans import Translator

def pdf_to_text(pdf_path):
    document = fitz.open(pdf_path)
    full_text = ""

    for page_num in range(len(document)):
        page = document.load_page(page_num)
        text = page.get_text()
        full_text += text + "\n"
    return full_text

def translate_text(text, src_lang='auto', dest_lang='en'):
    translator = Translator()
    translated = translator.translate(text, src=src_lang, dest=dest_lang)
    return translated.text

def pdf_to_translated_text(pdf_path, txt_path, dest_lang='en'):
    # Extract text from the PDF
    extracted_text = pdf_to_text(pdf_path)

    # Translate the extracted text
    #translated_text = translate_text(extracted_text, dest_lang=dest_lang)

    # Write the translated text to a file
    with open(txt_path, 'w', encoding='utf-8') as txt_file:
        txt_file.write(extracted_text)

pdf_to_translated_text('/home/albin/Downloads/Träningslärans_grunder.pdf', '/home/albin/Downloads/zig-linux-x86_64-0.14.0-dev.185+c40708a2c/workflow_chatbot/py_utils/data.txt')

