import { useState } from 'react';

type AccreditationType = 'accredited' | 'qualified' | 'retail' | 'institutional';

interface AccreditationCheckProps {
  onSelect: (type: AccreditationType) => void;
  jurisdiction: string;
}

export function AccreditationCheck({ onSelect, jurisdiction }: AccreditationCheckProps) {
  const [selected, setSelected] = useState<AccreditationType | null>(null);

  const options: { value: AccreditationType; label: string; desc: string }[] = [
    { value: 'accredited', label: 'Accredited Investor', desc: 'Meets income/net worth thresholds' },
    { value: 'qualified', label: 'Qualified Purchaser', desc: '$5M+ investable assets' },
    { value: 'retail', label: 'Retail Investor', desc: 'Standard investor protections' },
    { value: 'institutional', label: 'Institutional', desc: 'Bank, fund, or corporate entity' },
  ];

  function handleSelect(type: AccreditationType) {
    setSelected(type);
    onSelect(type);
  }

  return (
    <div className="accreditation-check">
      <h3>Investor Accreditation ({jurisdiction})</h3>
      <p>Select your investor category:</p>
      <div className="accreditation-options">
        {options.map(opt => (
          <button
            key={opt.value}
            className={`acc-option ${selected === opt.value ? 'selected' : ''}`}
            onClick={() => handleSelect(opt.value)}
          >
            <strong>{opt.label}</strong>
            <small>{opt.desc}</small>
          </button>
        ))}
      </div>
      {selected && <p>Selected: {selected}</p>}
    </div>
  );
}
