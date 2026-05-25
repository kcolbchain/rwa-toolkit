import { useState } from 'react';

interface GeographySelectorProps {
  onSelect: (geo: string) => void;
}

const JURISDICTIONS = [
  { code: 'US', name: 'United States' },
  { code: 'EU', name: 'European Union' },
  { code: 'UK', name: 'United Kingdom' },
  { code: 'SG', name: 'Singapore' },
  { code: 'CH', name: 'Switzerland' },
  { code: 'JP', name: 'Japan' },
  { code: 'HK', name: 'Hong Kong' },
  { code: 'AU', name: 'Australia' },
  { code: 'AE', name: 'UAE' },
  { code: 'IN', name: 'India' },
];

export function GeographySelector({ onSelect }: GeographySelectorProps) {
  const [selected, setSelected] = useState<string>('');

  function handleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const code = e.target.value;
    setSelected(code);
    onSelect(code);
  }

  return (
    <div className="geography-selector">
      <h3>Select Jurisdiction</h3>
      <p>Choose your country of residence for compliance purposes:</p>
      <select value={selected} onChange={handleChange}>
        <option value="">-- Select --</option>
        {JURISDICTIONS.map(j => (
          <option key={j.code} value={j.code}>{j.name} ({j.code})</option>
        ))}
      </select>
      {selected && <p>Selected: {selected}</p>}
    </div>
  );
}
