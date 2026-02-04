# CLI specification

How will we interact with the program?

## overview

Keep it simple stupid!! Unix is king, and we live by their philosophy

```sh
cat my-prompt-file.md | ralph "more prompt details" \
  --model=opus-4.5 \
  --max-iterations=10 \
  --duration=10 \
  --max-context=80000 \
  --completion="<promise>COMPLETE</promise>"
```
