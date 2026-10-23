#!/usr/bin/env python3
"""Check the supplied row measurements against native SwiftUI ImageRenderer output."""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parent.parent
constants = json.loads((root / 'Fixtures/constants.json').read_text())
directory = root / 'build/reference-renders'
heights = json.loads((directory / 'heights.json').read_text())
failures = []
results = []

for dark in (False, True):
    for row in constants['rows']:
        filename = f"row-{row['name']}{'-dark' if dark else ''}.png"
        height = heights[filename]
        errors = {'rowHeight': abs(height - row['rowHeight'])}
        image = Image.open(directory / filename).convert('RGB')
        bounds = None
        if not row.get('emojiOnly'):
            bubble = row['bubble']
            x, y = bubble['x'], bubble['yFromRowTop']
            sample = (int((x + bubble['width'] / 2) * 3), int((y + 5) * 3))
            color = image.getpixel(sample)
            mask = ImageChops.difference(image, Image.new('RGB', image.size, color))
            mask = mask.convert('L').point(lambda value: 255 if value == 0 else 0)
            if row.get('image'):
                blue = ImageChops.difference(image, Image.new('RGB', image.size, (60, 120, 195)))
                blue = blue.convert('L').point(lambda value: 255 if value == 0 else 0)
                mask = ImageChops.lighter(mask, blue)
            ImageDraw.floodfill(mask, sample, 128)
            mask = mask.point(lambda value: 255 if value == 128 else 0)
            box = mask.getbbox()
            if box:
                bounds = {'x': box[0] / 3, 'y': box[1] / 3,
                          'width': (box[2] - box[0]) / 3, 'height': (box[3] - box[1]) / 3}
                expected = {'x': x, 'y': y, 'width': bubble['width'], 'height': bubble['height']}
                errors.update({key: abs(value - expected[key]) for key, value in bounds.items()})
            else:
                failures.append(f'{filename}: could not identify bubble')
        for field, error in errors.items():
            if error > 2:
                failures.append(f'{filename}: {field} differs by {error:.2f} pt')
        results.append({'file': filename, 'height': height, 'bubble': bounds, 'errors': errors})
        print(f"{filename:32} maximum geometry error {max(errors.values()):.2f} pt")

report = {'tolerance': 2, 'results': results, 'failures': failures}
(directory / 'geometry-report.json').write_text(json.dumps(report, indent=2))
if failures:
    raise SystemExit('\n'.join(failures))
print('All 20 row renders meet the 2 pt geometry tolerance.')
