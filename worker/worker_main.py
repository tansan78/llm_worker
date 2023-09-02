from transformers import AutoModelForSeq2SeqLM
from transformers import AutoTokenizer
from transformers import GenerationConfig


def load_model(model_name='google/flan-t5-base'):
    model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    tokenizer = AutoTokenizer.from_pretrained(model_name, use_fast=True)

    return model, tokenizer


def main_loop():
    model, tokenizer = load_model()


if __name__ == "__main__":
    main_loop()
